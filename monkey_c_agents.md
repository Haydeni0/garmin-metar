# Monkey C Language Reference

This document serves as a comprehensive reference for the Monkey C programming language, designed for Garmin Connect IQ app development. It is structured to provide AI agents with a clear understanding of the language's syntax, semantics, and core libraries.

## 1. Overview
Monkey C is an object-oriented, duck-typed language with a syntax similar to Java, JavaScript, and Python. It is compiled into bytecode that runs on the Connect IQ Virtual Machine specifically optimized for low-power Garmin devices.

## 2. Lexical Structure

### Comments
```monkeyc
// Single line comment
/* Multi-line
   comment */
```

### Identifiers
Identifiers must start with a letter or underscore, followed by letters, underscores, or digits. They are case-sensitive.

## 3. Data Types

Monkey C uses a mix of primitive and reference types.

### Primitives
*   **Number**: 32-bit signed integer (e.g., `42`, `-1`, `0x2A`).
*   **Long**: 64-bit signed integer (e.g., `42l`, `0x2Al`).
*   **Float**: 32-bit floating-point (e.g., `3.14`, `1.0f`).
*   **Double**: 64-bit floating-point (e.g., `3.14d`).
*   **Boolean**: `true` or `false`.
*   **Char**: Unicode character literal (e.g., `'a'`).

### Reference Types
*   **String**: Sequence of characters (e.g., `"Hello"`).
*   **Symbol**: Lightweight immutable identifier (e.g., `:mySymbol`). Efficient for dictionary keys.
*   **Array**: Ordered indexed collection.
*   **Dictionary**: Key-value map.
*   **Object**: Base class for all class instances.

## 4. Variables and Constants

### Declaration
*   `var`: Declares a variable.
*   `const`: Declares a constant (cannot be reassigned).

```monkeyc
var x = 10;
var y; // Initialized to null
const PI = 3.14159;
```

### Scope
*   **Local**: Defined within a function/block.
*   **Instance**: Defined within a class.
*   **Static/Module**: Defined within a module (global to that module).

## 5. Arrays and Dictionaries

### Arrays
```monkeyc
// Fixed size
var arr = new [5]; 

// Initialization
var arr2 = [1, 2, 3, "four"];

// Access
var val = arr2[0];
arr2[1] = 50;

// Multi-dimensional
var grid = [[1, 2], [3, 4]];
```

### Dictionaries
Keys can be of any type (Symbols vary common). Hashing is used.
```monkeyc
var dict = { "key" => "value", :sym => 100 };
dict.put(1, "one");
var val = dict.get("key"); // or dict["key"]
```

## 6. Functions

Functions are first-class citizens (via `Method` objects) but are primarily defined within classes or modules.

```monkeyc
function add(a, b) {
    return a + b;
}

// Optional type checking (Connect IQ 4.0+)
function typedAdd(a as Number, b as Number) as Number {
    return a + b;
}
```

## 7. Classes and Objects

Monkey C is class-based with single inheritance.

```monkeyc
using Toybox.System;

class MyClass extends Lang.Object {
    // Member variables
    var mCount;
    hidden var mUiHidden; // 'hidden' access modifier

    // Constructor (Must be named 'initialize')
    function initialize() {
        mCount = 0;
    }

    function increment() {
        mCount++;
        System.println("Count: " + mCount);
    }
}
```

### Inheritance
Use `extends` to inherit.
`super` is typically inferred or not strictly required for method overrides unless disambiguation is needed, but `AppBase.initialize()` style calls are common in constructors.

## 8. Modules (`using` and `import`)

Modules organize code like packages.
*   `using Toybox.System;` allows `System.println()`.
*   `import Toybox.System;` allows `println()` (if unambiguous, though `using` is preferred for clarity).

## 9. Control Flow

Standard C-like control flow.
*   `if (condition) { } else { }`
*   `for (var i = 0; i < len; i++) { }`
*   `while (condition) { }`
*   `do { } while (condition);`
*   `switch (val) { case 1: break; default: }`
*   `return value;`
*   `throw new Lang.Exception();`
*   `try { } catch (ex) { } finally { }`

## 10. Key API Modules (Toybox)

The SDK provides libraries under the `Toybox` namespace.

*   **Toybox.Application**: App lifecycle (`AppBase`), settings (`Storage`).
*   **Toybox.WatchUi**: User interface (`View`, `Menu`, `Text`, `Bitmap`).
    *   `requestUpdate()`: Schedule a screen redraw.
*   **Toybox.Graphics**: Drawing primitives (`drawLine`, `drawText`, `setColor`).
*   **Toybox.System**: System info (`getDeviceSettings`), logging (`println`).
*   **Toybox.Communications**: Web requests (`makeWebRequest`), bluetooth.
*   **Toybox.Positioning**: GPS location (`Info`).
*   **Toybox.Sensor**: Biometrics (Heart Rate, Cadence).
*   **Toybox.Time**: Time and date manipulation (`Gregorian`, `Moment`).

## 11. Resources

Resources are XML-defined and compiled into a `Rez` module.
*   `Rez.Strings.AppName`
*   `Rez.Drawables.Icon`
*   `Rez.Layouts.MainLayout`

Usage: `WatchUi.loadResource(Rez.Strings.AppName)`

## 12. Annotations (Build Options)

*   `(:debug)`: Code only included in debug builds.
*   `(:release)`: Code only included in release builds.
*   `(:test)`: Code defining unit tests.
*   `(:background)`: Code available to background services.

## 13. Operator Precedence & Truthy/Falsy
*   Similar to C.
*   `null` is falsy.
*   `0` is **truthy** (unlike JS/C). Only `false` and `null` are false.

## 14. Weak References
Used to prevent reference cycles (e.g. View <-> Delegate).
```monkeyc
var weakRef = val.weak();
if (weakRef.stillAlive()) {
    var realVal = weakRef.get();
}
```

## 15. Exception Handling
It is recommended to catch specific exceptions.
```monkeyc
try {
    // risky code
} catch (ex instanceof Lang.InvalidValueException) {
    // handle
}
```
