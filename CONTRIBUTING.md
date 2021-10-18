# tl;dr

* If you have found a discrepancy in documented and observed behaviour, that
  is a bug.  Feel free to [report it as an
  issue](https://github.com/mpalmer/lacme/issues), providing
  sufficient detail to reproduce the problem.

* If you would like to add new behaviour, please submit a well-tested and
  well-documented [pull
  request](https://github.com/mpalmer/lacme/pulls).

* At all times, abide by the Code of Conduct (CODE_OF_CONDUCT.md).


# Development

See `.tool-versions` for the versions of the tools that are used in development.
The [`asdf`](https://asdf-vm.com/) tool can read the `.tool-versions` file and
automatically install and enable the various programs.

You'll probably want to install the pre-commit hook so that you get early warning
of formatting and other basic problems; from the root of the repo, run

```
ln -s ../../hooks/pre-commit.sh .git/hooks/pre-commit
```

to put it in place.

Before you submit a PR, please ensure that `terraform fmt` and `tfsec` don't
complain, and that all the test cases pass.  This will save a lot of fruitless
round trip conversations.


# Testing

There are a set of test cases in the `test/` directory which are designed to
exercise the L'ACME module.  See the `README.md` in that directory for the
full story.
