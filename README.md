# SwiftBasic-Core
**This project is a work in progress (including this README).** I'm (somewhat) confident that this is still riddled with bugs, and I know there are more featues I'd like to implement. If you find a bug or have a feature suggestion, don't be afraid to file an issue.

**For now, all rights are reserved.** Please don't use this in your projects just yet.

A dialect of Basic written in Swift, mostly inspired by [cvharihan's Basic](https://github.com/cvhariharan/Tiny-Basic) and [Commodore BASIC](https://www.c64-wiki.com/wiki/BASIC).

There are a few differences, though:

* Variables can store Ints, Doubles, or Strings.
    * Any math done with a Double will evaluate to a Double.

* Text labels are supported in addition to traditional integer labels (line numbers).
   
* Variable names beyond just single letters are possible - you can even use emoji, if you're into that.
   * You can also use emojis in labels.

* = is always the assignment operator, while == is always the equality operator.

* Compound assignment operators are supported (`+=`, `-=`, `*=`, `/=`, and `%=`).
    * For example, `A %= 5` is equivalent to `A = A % 5`.

* There is an infix power operator (`**`) that always evaluates to a Double (for the sake of simplicity).

* LIST lists the variables in memory (or, more accurately, passes the list to a delegate), not the program itself.

* Arrays are not supported - instead, there are dictionaries (because swift makes using them easier). You can use them just as you would an array, if you want.

Usage notes:

* Some sort of care should be taken when considering programs that do not terminate on their own.
    * In a GUI application, BasicParser.run() should be called on a background thread so that your main thread doesn't lock up if the program in memory is an infinite loop of some sort.

