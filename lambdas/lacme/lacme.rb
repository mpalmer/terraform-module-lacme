require "acme-client"
require "aws-sdk-acm"
require "aws-sdk-kms"
require "aws-sdk-dynamodb"
require "openssl"

RENEWAL_GRACE_PERIOD_DAYS = 30
RENEWAL_GRACE_PERIOD_SECONDS = RENEWAL_GRACE_PERIOD_DAYS * 86400

def not_found
	{
		statusCode:        404,
		statusDescription: "404 Not Found",
		headers: {
			"Content-Type" => "text/plain",
		},

		body:            "Not Found",
		isBase64Encoded: false,
	}
end

def response(token)
	{
		statusCode:        200,
		statusDescription: "200 OK",
		headers: {
			"Content-Type" => "text/plain",
		},

		body:            token,
		isBase64Encoded: false,
	}
end

def table_name
	ENV.fetch("DYNAMODB_TABLE_NAME")
end

def logger
	@logger ||= Logger.new($stderr).tap { |l| l.formatter = ->(_, _, _, m) { "#{m}\n" } }
end

def aws_log_formatter
	Aws::Log::Formatter.new("[:client_class :http_response_status_code :time :retries retries] :operation(:request_params) :error_class :error_message\n:http_response_headers\n")
end

def dynamodb
	@dynamodb ||= Aws::DynamoDB::Client.new(logger: logger, log_formatter: aws_log_formatter)
end

def serve_challenge(event:, context:)
	key = event["path"]

	unless key =~ %r{\A/.well-known/acme-challenge/[a-zA-Z0-9_-]+\z}
		# Nice try, wily hacker
		return not_found
	end

	item = dynamodb.get_item(key: { "k" => "challenge:#{key}" }, table_name: table_name, consistent_read: true).item

	if item.nil?
		return not_found
	else
		return response(item["v"])
	end
end

def acme_directory
	ENV.fetch("ACME_DIRECTORY_URL")
end

def db_item(k)
	dynamodb.get_item(key: { "k" => k }, table_name: table_name, consistent_read: true).tap { |r| p :DB_ITEM, table_name, k, r }.item
end

def acm_cert_arn
	ENV.fetch("ACM_CERTIFICATE_ARN")
end

def cert_names
	ENV.fetch("CERTIFICATE_NAMES").split(/\s*,\s*/)
end

def cert
	cert_item = db_item("certificate")

	if cert_item.nil?
		# A minimally-functional "null" cert that the rest of the code can use
		OpenSSL::X509::Certificate.new.tap do |c|
			c.version = 2
			c.serial  = 1

			c.subject = OpenSSL::X509::Name.new([["CN", "null"]])
			c.issuer  = c.subject

			c.not_before = Time.at(0)
			c.not_after  = Time.at(0)
			c.extensions = [OpenSSL::X509::Extension.new("subjectAltName", "")]
		end
	else
		OpenSSL::X509::Certificate.new(cert_item["v"])
	end
end

def cert_sans
	san_ext = cert.extensions.find { |ext| ext.oid == "subjectAltName" }
	san_ext.value.split(/\s*,\s*/).select { |s| s.start_with?("DNS:") }.map { |s| s[4..-1] }
end

def acm
	@acm ||= Aws::ACM::Client.new
end

def store_challenge(challenge)
	dynamodb.put_item(item: { k: "challenge:/#{challenge.filename}", v: challenge.file_content, ttl: Time.now.to_i + 900 }, table_name: table_name)
end

def lock(id)
	p :LOCK_ATTEMPT, id

	dynamodb.put_item(
		table_name: table_name,
		item: { k: "activity_lock", v: id, ttl: Time.now.to_i + 1200 },
		condition_expression: "attribute_not_exists(k) OR v = :v",
		expression_attribute_values: { ":v" => id }
	)
	p :LOCK_ACQUIRED, id
rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => ex
	p :LOCK_FAILED, ex
	sleep 5
	retry
end

def unlock
	p :LOCK_RELEASED
	dynamodb.delete_item(key: { k: "activity_lock" }, table_name: table_name)
end

def initialize_account_key
	$stderr.puts "CREATING NEW ACME ACCOUNT KEY"

	OpenSSL::PKey::RSA.new(2048).tap do |account_key|
		dynamodb.put_item(item: { k: "account_key", v: account_key.to_pem }, table_name: table_name, expected: { k: { exists: false } })

		Acme::Client.new(private_key: account_key, directory: acme_directory).new_account(contact: nil, terms_of_service_agreed: true)
	end
end

def account_key
	account_key_item = db_item("account_key")

	if account_key_item.nil?
		initialize_account_key
	else
	  OpenSSL::PKey.read(account_key_item["v"])
	end
end

def kms_key_id
	ENV.fetch("KMS_KEY_ARN")
end

def kms?
	kms_key_id != ""
end

def kms
	@kms = Aws::KMS::Client.new
end

def kms_key
	@kms_key ||= kms.describe_key(key_id: kms_key_id)
end

def store_private_key(pem)
	kms.encrypt(key_id: kms_key_id, plaintext: pem).tap do |res|
		dynamodb.put_item(item: { k: "private_key", v: [res.ciphertext_blob].pack("m0") }, table_name: table_name)
	end
end

def issue_cert(event:, context:)
	p :EVENT, event
	p :CONTEXT, context

	p :CERT_SANS, cert_sans
	p :WANTED_NAMES, cert_names
	p :EXPIRY, cert.not_after

	# This function gets run regularly, often when there's no need to issue
	# a new cert, so let's get that out of the way first.
	if cert_sans.sort == cert_names.sort && Time.now + RENEWAL_GRACE_PERIOD_SECONDS < cert.not_after
		$stderr.puts "Cert looks OK; not doing anything"
		return
	end

	lock(context.aws_request_id)

	acme_client = Acme::Client.new(private_key: account_key, directory: acme_directory)
	order = acme_client.new_order(identifiers: cert_names)

	# While it may seem odd to have two iterations over the same set of
	# values one after the other, separating them like this lets the ACME
	# server perform the validations in parallel, which greatly improves
	# the time required to complete the order.
	order.authorizations.each do |auth|
		store_challenge(auth.http)
		auth.http.request_validation
	end

	order.authorizations.each do |auth|
		while auth.http.status == "pending"
			p :PENDING, auth.domain
			sleep 2
			auth.http.reload
		end

		p :AUTH_COMPLETE, auth.domain

		unless auth.http.status == "valid"
			p :AUTH_STATUS, auth.domain, auth.http.status
			$stderr.puts "Failed validation for #{auth.domain}!"

			# It's best to tidy up our authorizations, to avoid rate-limit issues
			order.authorizations.each { |a| a.deactivate rescue nil }

			return
		end
	end

	while order.status == "valid"
		p :ORDER_WAITING
		sleep 1
		order.reload
	end

	cert_key = OpenSSL::PKey::RSA.new(2048)

	csr = Acme::Client::CertificateRequest.new(private_key: cert_key, subject: { common_name: cert_names.first }, names: cert_names)
	order.finalize(csr: csr)
	while order.status == "processing"
		p :ORDER_PROCESSING
		sleep 1
		order.reload
	end

	cert, *chain = order.certificate.scan(/.*?-----END CERTIFICATE-----/m)

	p :CERT_STORE
	dynamodb.put_item(item: { k: "certificate", v: cert }, table_name: table_name)
	dynamodb.put_item(item: { k: "chain", v: chain.join }, table_name: table_name)

	if kms?
		p :KEY_STORE
		if kms_key.key_metadata.key_usage == "ENCRYPT_DECRYPT"
			store_private_key(cert_key.to_pem)
		else
			$stderr.puts "ERROR: key usage for specified KMS key is #{kms_key.key_metadata.key_usage}; require 'ENCRYPT_DECRYPT'"
		end
	end


	p :CERT_IMPORT
	acm.import_certificate(certificate_arn: acm_cert_arn, certificate: cert, private_key: cert_key.to_pem, certificate_chain: chain.join)
ensure
	unlock
end
