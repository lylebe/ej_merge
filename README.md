ej_merge [![Build Status]]
========

This module provides a pure Erlang support for JSON Patch (RFC 6902) and 
JSON Merge Patch (RFC 7396) specifications.  Both provide mechanisms 
that permit patching of an existing update object using the HTTP PATCH 
method.  This module supports the underlying patch functions (not the 
HTTP PATCH method itself).
 
The Target and Patch documents accept any structure JSON format 
supported by the ej module (http://github.com/seth/ej).  

Module
------

* ej_merge : The module implementing both patch functions

Usage
-----

Below is an example using mochijson2 with the mergepatch function from 
RFC 7396.

A="{ \"a\": \"b\", \"c\": { \"d\": \"e\", \"f\": \"g\" } }".
B="{ \"a\": \"z\", \"c\": { \"f\": null } }".
ej_merge:mergepatch( mochijson2:decode(A), mochijson2:decode(B) ).

References
----------

Related work:

*[ej: Helper module for working with Erlang terms representing JSON](https://github.com/seth/ej)
