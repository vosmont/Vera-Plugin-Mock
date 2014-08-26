# Vera-Plugin-Mock

Mock for local testing **outside** of Vera.

It implements main core functions. See MicasaVerde wiki for more description of the luup functions and variables.
http://wiki.micasaverde.com/index.php/Luup_Lua_extensions

# Installation

Download and install ZeroBraneStudio (a lightweight IDE for Lua).
https://github.com/pkulchenko/ZeroBraneStudio

Configure your project directory and set the Lua interpreter on 'Lua'.

# Test your scripts

Put your script in the folder "script" (a skeleton is present in this folder) and run it !

# Unit testing

A modified version of 'luaunit' is present in lib folder to test the mock and your scripts for Vera.

It is based on 'rjpcomputing' version.
https://github.com/rjpcomputing/luaunit

There's also another newer version (but not used here) :
https://github.com/bluebird75/luaunit

See 'test/test_core_vera.lua' for examples.
