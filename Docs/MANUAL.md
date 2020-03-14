# SwiftBasic Programmer's Guide (under construction)

## Table of Contents

1. Introduction
2. [Variables and Data Types](#Variables and Data Types)
3. Expressions and Operators
   1. Assignment Operators
   2. Arithmetic Operators
   3. Bitwise Operators
   4. Comparison Operators
4. Chapter 3
5. Chapter 4

### Introduction

* Some sort of introduction. Lays the groundwork for the next section.

### Variables and Data Types

SwiftBasic allows variable names of any size, as long as the name doesn't contain a special character and doesn't conflict with a keyword or the name of a built-in function.

SwiftBasic supports the following data types, both in variables and as literal (constant) values:

* Integers
* Floating Point Numbers
* Strings
* Dictionaries

A variable can store any of these values. Be aware that the data type of a variable may change if you assign a value of a different type to it.

#### Integers

Integers are whole numbers. These can range from -2<sup>63</sup> to 2<sup>63</sup>-1 on a modern 64-bit device. Here are a few examples of integer literals:

* `1234`
* `-1`
* `0`
* `34964284560`

Careful: Don't put commas inside any number -- SwiftBasic won't be able to understand the number because commas are a special character.

#### Floating Point Numbers

In SwiftBasic, floating point numbers are numbers with a decimal point. SwiftBasic uses double-precision floating point numbers under the hood, so they can generally range in value from about -1.8\*10<sup>308</sup> to 1.8\*10<sup>308</sup>, though not every number in that range can be represented precisely. There are also values for positive and negative inifinity. 

Here are a few examples of floating point literals:

* `12.12`
* `0.1234`
* `-.567`
* `-2.3456e5` (equivalent to `-234560.0`) 
* `pi` or `π`
* `inf` or `Infinity`

Keep in mind that, because of the limited precision of floating point numbers, certain values might be a tiny bit "off" from time to time. 

You may also encounter NaN (not a number) if your program tries to perform an impossible calculation.

#### Strings

Strings are a block of text between two quotation marks. There aren't any particular limitations on the size of a string, but it must be all on one line (SwiftBasic does not currently support multi-line strings).

Here are a few examples of string literals:

* `"Hello, world!"`
* `"Welcome to SwiftBasic!"`
* `"12345"`
* `""`

SwiftBasic doesn't currently allow escaping characters - in other words, backslash currently has no special meaning.

#### Dictionaries

Dictionaries allow you to store other values inside them. Each dictionary has a set of keys and each key has one associated value. These keys and values can be any data type SwiftBasic supports.

You can initialize SwiftBasic dictionaries with or without keys. If you omit a key for a value in a dictionary literal, an auto-incrementing integer key will be assigned to it. In either case, a dictionary literal begins with a `[` and ends with a `]`. If want to choose a key yourself, place it before a colon (`:`), and place its corresponding value after the colon. Separate key:value pairs with commas.

Here are a few examples of SwiftBasic dictionary literals:

* `[0:"Hello"]`
* `[0:0,1:1,2:2]`
* `[0,1,2]` (equivalent to `[0:0,1:1,2:2]`)
* `[]`
* `["a":10,"b":20]`
* `["students":["Steve", "Joe"], "teachers":["Ms. Smith", "Mr. Gates"]]`

Note: Unlike an array, a Dictionary has no guaranteed order in memory. As a result, when you PRINT a dictionary, the elements will not necessarily be printed out in the order in which you added them.

Also, while you can nest dictionaries as deeply as possible and read from nested dictionaries easily, writing directly to those nested dictionaries is not currently supported.

### Expressions and Operators

Expressions are composed of operators and values. Expressions can be a single value of any type or a composition of values separated by operators.

Operators are a sequence of one or two special characters that go between two values that SwiftBasic recognizes as representing an operation to perform on those two values.