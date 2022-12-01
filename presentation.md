---
title: Nix Knowledge Sharing
author: Alexander Bantyev @balsoft
date: 2022-12-01
aspectratio: 169
mainfont: Ubuntu
monofont: Ubuntu Mono
sansfont: Oswald
header-includes:
  - \usepackage[outputdir=_output]{minted}
  - \usemintedstyle{borland}
---

## Intro/Contents

::: notes
Today, we're going to have a quick refresher of the Nix language and ecosystem.
:::

- Nix Language Refresher
- Nix Ecosystem Overview

# Nix Language Refresher

::: notes
This is going to be a quick refresher of some Nix language features. This
assumes some knowledge already, and will mostly focus on commonly confusing
bits.
:::

## Overview

::: notes

"Nix" can be used to refer to both the language and the build system. Here, we
will mostly refer to it as the language, since it's the bit that's interesting
for us.

Nix is an purely functional language. That means that there are no variables or
state, only bindings, function definitions, and function applications.

Nix is lazy, meaning the values are only evaluated if they are needed.

Nix is not statically typed, meaning there's no way to statically guarantee that
a value will have a certain type.

Nix is not supposed to be a general-purpose language. It's a DSL for generating
derivations, which are detailed and self-contained build instructions for the
Nix build system. You can think of derivations (.drv files) as sexp files
containing detailed information about dependency relations, required CPU
architecture and system features, and the exact commands needed to build the
package.

With this goal in mind, let's get a quick overview of the language features.

:::

```
<file>.nix
|
| [Nix language evaluation]
V
/nix/store/<hash>-<package>.drv
|
| [Nix build system "realisation" (building)]
V
/nix/store/<hash>-<package>
```

## Primitives, lists, let..in

::: notes

Nix supports all the primitives you would expect from a JSON-like language:
ints, floats, a unit-type null, bools, lists, and strings.

Ths list literal has element separated by whitespace (WHICH WAS A MISTAKE).

There are two string literals: one for single-line strings, one for "multiline"
strings. Both string literals can actually be split over multiple lines, but the
non-multiline literal will keep the indentation. Both string literals support
string interpolation.

A `let..in` expression is a way of assigning multiple bindings, possibly using
other bindings from the same `let..in` expression, and then using them in the
"body". Note that bindings are not variables, i.e. they may not be mutated. You
can shadow bindings from outer scope within the `let..in` binding.

:::


```nix
let
  int = 123; # This is a comment!
  bool = false;
  list = [ 123 true "foo" ]; # Note that whitespace is the element separator
  example = "like this";
  str = "This is a string. It supports string interpolation: ${example}.
    You can convert other values to string using ${toString int}.
    Doing ${toString null} will yield an empty string.
    You can also use escape sequences, comme ça: \t\n";
  multilineString = ''
    Strings can also be multiline.
    Here, the smallest common indentation is removed from all lines.
    In this example, the four spaces to the left will be removed.
  '';
in "Finally, strings can be concatenated: " + str + multilineString
```

## Attribute sets

::: notes

Attribute sets are an analog of JSON objects. They map string keys to arbitrary
values. The syntax is key, then `=`, then the value. `outPath` attribute will be
used when the set is converted to a string, either explicitly with `toString` or
implicitly by just interpolating it.

:::

```nix
let
  attrset = {
    this = "attribute set";
    key = "value";
    "keys can be any string" = true;
    outPath = "Confusingly, this attribute will be used when converting to string";
  };
  example-key = "keys can be any string";
in ''
  Accessing the keys of the attrset is done with the . operator: ${attrset.key}
  (or ${toString attrset.${example-key}} for dynamic key names).
  The or operator can be used for fallback: ${attrset.foo or "default value"}
  The attrset can be converted to JSON: ${__toJSON attrset},
  or turned to a string explicitly: ${toString attrset},
  or interpolated directly: ${attrset}.
  ${attrset.outPath} will be used for the latter two.
''
```

## Attrsets: syntactic sugar, operators

::: notes

Because attrsets are so common in the Nix language, there's quite a lot of
syntactic sugar around them.

The `//` operator merges two attribute sets together.

:::

```nix
let
  attrset1 = {
    foo.bar = "baz"; # same as foo = { bar = "baz"; };
  };
  attrset2 = {
    inherit attrset1; # same as attrset1 = attrset1;
    inherit (attrset1) foo; # same as foo = attrset1.foo;
  };
in attrset2 // attrset1.foo # { attrset1 = ...; foo = ...; bar = ...; }
```

## Lambdas

::: notes

Since Nix is a functional language, lambdas are a first-class citizen of the
language, and the main way of building abstractions.

The syntax for lambdas is an argument name, then a colon (:), and then the
lambda body.

Lambda application is just the lambda, then whitespace, then the argument.

If you want to have a function of multiple arguments, you can use currying.

Alternatively, you can also use pattern matching (which is actually
destructuring) on attribute sets to have a function which has multiple
arguments, while only technically having one. The syntax for destructuring is
attribute names separated by commas, in curly brackets. You can also use `?` to
set default values (which can be overriden if necessary) and use `...` to accept
attribute sets which have extraneous keys (otherwise calling the function with
such a set would be an error).

Lambdas can be recursive, but beware: it's easy to hit infinite recursion, thus
breaking evaluation. Remember, our final goal is not a general-purpose language,
but just a way to generate fancy sexps for the build system.

:::

```nix
let
  things = "this is an example binding";
  lambda = argument: "body, which may use the ${argument} and ${things} from scope";
  application = lambda "example argument";
  listOfApplications = [ (lambda "foo") (lambda "bar") ]; # Note the parenthesis!
  curried = arg1: arg2: arg1 + arg2;
  curriedApplication = curried 2 3; # => 5
  patternMatch = { key1 , key2 ? 3, ... }: key1 + key2;
  patternMatchApplication = patternMatch { key1 = 5; }; # => 8
  recursive = arg: if arg < 1 then 1 else arg * recursive (arg - 1); # Factorial
in recursive 5 # => 120
```

## Built-in functions, derivations

::: notes

Nix has some useful built-in functions, most of them accessible from the
`builtins` attribute set.

One really important built-in function is `derivation`. It takes an attribute
set as an argument, does some "magic" inside, and returns you a path to the
(potentially not yet existing) result of executing the `builder` with the
`args`, in the environment specified by all the other arguments (e.g. you can
set env variables by just passing them as attributes). This is really cumbersome
to use for packaging directly, but is the basis for many abstractions. We will
look at some of them later.

The derivations are executed inside a sandbox, with heavy restrictions on what
is accessible, to help with reproducible packaging. In particular, most of the
filesystem access is restricted (only explicitly mentioned dependencies are
available), some syscalls are restricted, etc.

Another important limitation is that Nix only allows internet access inside the
sandbox if you use a so-called "fixed-output derivation", telling Nix the
checksum of the expected derivation output. Nix will only allow the build to
continue if the actual checksum of the output matches the expected one. This
ensures that if the resources on the network are modified, the build fails,
instead of producing a different result.

:::

```nix
let
  # See nixos.org/manual/nix/stable/language/builtins.html for more
  example1 = map (x: x + 1) [ 3 4 5 ]; # => [ 4 5 6 ]
  example2 = # => { foo = 11; goo = 21; }
    builtins.mapAttrs
    (key: value: value + 1)
    { foo = 10; goo = 20; };
  drv = derivation {
    name = "example-derivation";
    system = "x86_64-linux";
    NAME = "nixer";
    builder = "/bin/sh";
    args = [ "-c" "echo hello $NAME > $out" ];
  };
in drv
```

## Project structure: paths & import

::: notes

Because of Nix's niche, it's quite useful to have the ability to refer to paths
relative to the file we're evaluating. This is used for specifying "local"
sources of packages. Relative paths begin with `./`.

Paths can also be used to split up the Nix code into multiple files, using
`import`.

:::

### `file.nix`

```nix
{
  example = 123;
}
```

### `other-file.nix`

```nix
arg: {
  foo = "${arg} bar";
}
```

### `default.nix`
```nix
let
  path = ./example-path/file.whatever;
  imported = import ./file.nix; # => { example = 123; }
  other-imported = import ./other-file.nix "goo";
  # Note that this is just function application. We could have also written
  # (import ./other-file.nix) "goo"
in other-imported.foo # => "goo bar"
```

## Flakes

::: notes

Now that we're somewhat up to speed with the language syntax, how do we actually
evaluate those files? Well, there's an old way to just evaluate arbitrary Nix
files, but there's also a new, more convenient and reproducible way: flakes.
They offer easy dependency management, hermetic evaluation, a standard project
structure, and a nice command-line interface. They are kind of what Cargo is to
Rust. Sure, you can build your `.rs` files manually with `rustc`, but why do
that when you can use `cargo run`?

To use flakes, you need to make sure your Nix is recent enough, and that
`nix-command` and `flakes` experimental features are enabled.

A flake is basically a directory containing `flake.nix` file. That file should
be an attribute set with certain keys. For now, let's only concern ourselves
with `outputs`.

`outputs` is a function which takes an attribute set (of inputs) and returns an
attribute set. That attribute set can have arbitrary keys, but some keys are
standard and recognized by various Nix utilities, so it's better to use those
whenever applicable.

You can use `nix eval` or `nix repl` to inspect the flake's outputs.

:::

### `flake.nix`

```nix
{
  outputs = { self }: {
    foo = "bar";
  };
}
```

### Shell

    $ nix eval .#foo
    "bar"
    $ nix repl
    nix-repl> :lf .
    nix-repl> foo
    "bar"

## Flakes: inputs, nixpkgs

::: notes

As mentioned previously, flakes can have inputs. A very common dependency in
Nix-based projects is nixpkgs, a massive repository of packages for the Nix
build system.

To add a dependency on nixpkgs, let's add an `inputs` attribute to the flake,
and a corresponding argument to `outputs`.

We can then use some package from nixpkgs to make ourselves a "development"
shell (which is basically a shell with some utilities available).

We can then use `nix develop` to drop ourselves into this shell. Whenever you
perform any operation on the flake, Nix will make sure that the `flake.lock`
file is consistent with the `inputs` in `flake.nix`, and update if necessary.
The fact that all dependency versions and hashes are locked in the `flake.lock`
file ensure that if you share this directory with anyone, they will get exactly
the same package versions as you.

:::

### `flake.nix`

```nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default =
        pkgs.mkShell { packages = [ pkgs.hello pkgs.coreutils ]; };
    };
}
```

### Shell

    $ nix develop .
    $ hello | rev
    !dlrow ,olleH

# Nix Ecosystem Overview

::: notes

In this chapter, we'll take an overview of the Nix ecosystem, and how software
is usually packaged with it. Since nixpkgs is so massive and important, its
convensions are basically _the_ Nix ecosystem conventions, so it's worth taking
a look at them.

:::

## nixpkgs stdenv: `mkDerivation`, `runCommand`

::: notes

As noted in the previous chapter, using `derivation` directly is not very
convenient. We have to get the dependencies, even compilers, from somewhere, and
then call them manually with all the flags that they might need. So, nixpkgs
provides us with a convenient abstraction on top of `derivation`:
`stdenv.mkDerivation`. `stdenv` stands for "standard environment", and it's a
collection of "stuff" to facilitate building many different packages, but mostly
focused on the lingua franca: C/C++. It includes a C/C++ compiler, shell,
coreutils, and some other useful tools (`make`, `grep` etc).

The `mkDerivation` function is really versatile, and therefore complex. The most
common use is to pass it a `pname` (package name), `version` an `src` (which is
a path to the source directory). It will then unpack the source, try configuring
it by running `./configure`, then try building it by running `make` and finally
install it with `make install` (passing some flags where appropriate). When you
want to do something else for configuration, building and installation (which is
the case most of the time), you can pass `configurePhase`, `buildPhase` and
`installPhase`. If you some extra binaries to be available, or pass some
libraries to the compiler, you can add them as derivations to
`nativeBuildInputs` and `buildInputs` correspondingly.

This just scratches the surface of capabilities of `mkDerivation`. Consult the
[nixpkgs manual](https://nixos.org/nixpkgs/manual) for more details.

:::

```nix
stdenv.mkDerivation {
  pname = "package";
  version = "1.0.0";
  src = ./package;
  configurePhase = "./configure --prefix=$out";
  buildPhase = "make";
  installPhase = "make install";
  # Imagine `bar` is a build tool,
  nativeBuildInputs = [ bar ];
  # And `libfoo` is a library.
  buildInputs = [ libfoo ];
}
```

::: notes

There's also a useful abstraction on top of `mkDerivation`: `runCommand`. It
takes three argument: package names, arguments as in to `mkDerivation`, and a
build script. It's mostly used for executing a couple commands and gathering
their result in a derivation output.

:::

```nix
runCommand "greeting" { nativeBuildInputs = [ hello ]; } ''
  hello > $out
''
```

## `overrideAttrs`

::: notes

Sometimes we want to alter the derivation just a little bit, while keeping most
of it as-is. For this, `mkDerivation` result has a special `overrideAttrs`
attribute. It's a function which takes a function, passes the "old" attributes
to it, and returns the result of it merged with the old attributes.

:::

```nix
let package = stdenv.mkDerivation { pname = "package"; /* ... */ }; in
package.overrideAttrs (oa: { pname = "${oa.pname}-foo"; })
# Will produce a package with `pname = "package-foo"`
```

## Packaging conventions

::: notes

All packages in nixpkgs are expressed as functions, taking an attribute set of
their dependencies and returning a derivation which, when executed, builds the
package.

Then, all those packages are united into a single attribute set (called a
package set, or a scope), using some "magic" fixed points.

:::

### `package.nix`

```nix
{ stdenv, libfoo, bar }: stdenv.mkDerivation { /* ... */ }
```

### `all-packages.nix`

```nix
# Fix combinator; You can think of it as "iterate this function repeatedly".
let fix = f: let x = f x; in x; in
# It might be a bit confusing when used on a package scope.
# I encourage you to think through it at some point, though, it can be a rewarding a-ha!
fix (scope: {
  stdenv = import ./stdenv.nix { };
  libfoo = import ./libfoo.nix { };
  bar = import ./bar.nix { };
  package = import ./package.nix { inherit (scope) libfoo bar; };
  # This is just syntactic sugar for
  # package = import ./package.nix { libfoo = scope.libfoo; bar = scope.bar; };
})
```
## Scopes, `callPackage`, `override`

::: notes

In the example above, we've repeated the names of the dependencies three times.
This turns out to be inconvenient, so nixpkgs provides us some nice functions in
its standard library (found in `nixpkgs.lib`) to get rid of some repetition.

I will simplify a lot here, since the details are really complicated and not
imporant for our goals.

The `makeScope` function takes a "scope" and "fixes" it, as on the previous
slide. However, now there's a twist: it also injects a `callPackage` function in
the scope. This function magically figures out the arguments which it needs to
supply to each package. The last argument of callPackage can be used for
overrides, or to add packages from outside the scope.

This allows us to almost never explicitly pass dependencies to the packages.

As I said, don't worry about the details; just remember that `scope.callPackage`
is magic that passes packages from scope into functions.

`callPackage` also adds a special attribute `override` to whatever package it
calls. It allows you to "override" the arguments of the function it calls.

:::

### `all-packages.nix`

```nix
lib.makeScope (scope: {
  libfoo = scope.callPackage ./libfoo.nix { };
  bar = scope.callPackage ./bar.nix { };
  package = scope.callPackage ./package.nix { };
  package-without-bar = scope.callPackage ./package.nix { bar = null; };
  # Or, the same:
  # package-without-bar = scope.package.override { bar = null; };
})
```

## Overlays

::: notes

It can be really useful to add or change packages in the package set. This is
accomplished with overlays. Every scope also has a special attribute called
`extend`, which accepts a function of two arguments (called an "overlay"), and
specially applies that function to the scope.

The first argument of an overlay is the "final" state of the scope, after all
overlays are applied. It can sound contradictory, but due to laziness, the fix
point allows us to do that. However, be wary, as it's really easy to introduce
infinite recursion here.

The second argument is the "previous" state of the scope, as in the scope before
this overlay is applied. This makes overlays inherently ordered. Only use `prev`
when the use of `final` would result in an infinite recursion, such as when
you're changing a package in the scope.

There's also a couple of function in nixpkgs for combining overlays together.
The most convenient one is `lib.composeManyExtensions`, which takes a list of
overlays and returns a new one which is equivalent to overlays applied one after
each other in order.

This concludes the nixpkgs architecture basics; There's obviously a lot more to
know about such a massive and complex package repository. Check out the nixpkgs
manual to learn more.

:::

```nix
let
  pkgs = lib.makeScope (scope: { /* ... */ });
  overlay1 = final: prev: {
    package = prev.package.override { bar = null; };
    new-package = final.callPackage ./new-package.nix { };
  };
  # Just for demonstration
  pkgs' = pkgs.extend overlay1;
  overlay2 = final: prev: {
    # Note that this change will automatically propagate to all transitive deps of libfoo
    libfoo = prev.libfoo.overrideAttrs (_: { configureFlags = [ "--with-goo" ]; });
  };
in pkgs.extend (lib.composeManyExtensions [ overlay1 overlay2 ])
```

## language-to-nix tools

::: notes

Modern programming languages often come with their own dependency managers
(sometimes multiple). This `cargo` for Rust, `npm` for Javascript, `cabal` for
Haskell, etc. These dependency managers typically operate by reading some
package desciption, figuring out what dependencies are needed, downloading them
from the internet, and then installing them. This usually works fine, however,
as discussed previously, Nix generally forbids internet access inside the
sandbox, and, as such, the dependency managers can't do this really important
step.

As such, an important part of Nix ecosystem are tools which solve this problem.
Typically they are unimaginatively called "$language2nix"

Usually, the tool figures out which packages need to be downloaded, and out what
the checksum of the source is (e.g. from the lockfile); Then it downloads them
as fixed-output derivations.

There are two ways such tools actually build the package:

- Some tools just "vendor" all the dependency sources somewhere for the
  language's package manager to find, and then lets the package manager build
  all of them.
- Other tools go a step further, and build every dependency as a separate
  derivation (using `mkDerivation`), only using the language's build system (and
  not the package manager).

For example, `opam-nix` is a tool which takes an opam package description and
builds it with Nix. It builds each dependency as a separate derivation, which
allows for both reproducibility and caching. This example flakes show how to
build a simple opam-based project with opam-nix.

:::

### `flake.nix`

```nix
{
  inputs.opam-nix.url = "github:tweag/opam-nix";
  outputs = { self, opam-nix }: {
    # Figures out which dependencies are needed by my-package
    # Downloads and builds them, and then builds my-package with those dependencies
    packages.x86_64-linux.default =
      (opam-nix.lib.x86_64-linux.buildOpamProject { } "my-package" ./. { }).my-package;
  };
}
```

### Shell

    nix build
    ./result/bin/my-package

## `flake-utils`

::: notes

You might have noticed that in all our previous flake examples, we hardcoded the
"system" (CPU architecture and OS). This is needed because each derivation can
only be built on a particular system, because it and its dependencies all depend
on some platform-specific bootstrap tooling. It's not good to hardcode such
things, because we might want to build the packages on other platforms.

This can be solved in multiple ways, e.g. by mapping over a list of platforms in
nixpkgs with `mapAttrs`. However, there's a more convenient way: `flake-utils`.

It provides functions `forEachSystem` and `forEachDefaultSystem`, which map over
corresponding systems and then interleave the per-system attribute sets as
needed.

For example, the following flake is identical to the previous one, except more
systems can be easily added by just appending them to the list passed to
`eachSystem`.

:::

```nix
{
  inputs.opam-nix.url = "github:tweag/opam-nix";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, opam-nix, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" /* more systems can be added */ ] (system: {
      packages.default =
        (opam-nix.lib.${system}.buildOpamProject { } "my-package" ./.
          { }).my-package;
    });
}
```

## Thank you!

- Presentation: <https://github.com/balsoft/nix-knowledge-sharing>