# SwiftBasic-Core
**This project is a work in progress (including this README).** I'm confident that this is still riddled with bugs, and I know there are more featues I'd like to implement. If you find a bug or have a feature suggestion, don't be afraid to file an issue.

**For now, all rights are reserved.** Please don't use this in your projects just yet.

A dialect of Basic written in Swift, mostly inspired by [cvharihan's Basic](https://github.com/cvhariharan/Tiny-Basic) and [Commodore BASIC](https://www.c64-wiki.com/wiki/BASIC).

There are a few differences, though:

* Variables can store Ints or Doubles.
    * Any math done with a Double will evaluate to a Double.

* Text labels are supported in addition to traditional integer labels.

* Variable names beyond just single letters are possible - you can even use emoji, if you're into that.

* = is always the assignment operator, while == is always the equality operator.

* Compound assignment operators are supported.

* LIST lists the variables in memory (or, more accurately, passes the list to a delegate), not the program itself.
