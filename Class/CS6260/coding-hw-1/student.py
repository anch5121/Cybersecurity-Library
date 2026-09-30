#!/usr/bin/env python3

from typing import Tuple

# Feel free to import anything you need from the standard library.
import oracle
import crypto


def main(message: bytes, injection: bytes) -> Tuple[bytes, str]:
    """ Your goal is to bypass the oracle's integrity check.

    This will break UF-CMA security of the scheme and demonstrate a length
    extension attack on the underlying SHA1 hash function, which relies on the
    Merkle-Damgard construction internally.

    Specifically, you must somehow craft a message that includes the given
    parameter WITHIN the default message AND find a valid tag for it WITHOUT
    querying the oracle.

    Your attack should be able to inject any message you want, but we want you
    to include your GT username (as bytes) specifically.
    """
    if not isinstance(message, bytes) or not isinstance(injection, bytes):
        raise TypeError(f"expected bytes as args, got {type(message)} and {type(injection)}")

    #
    # The following is all purely sample code to familiarize yourself with some
    # of the available functions and methods. Different approaches to the
    # problem may or may not need certain functions.
    #
    # We highly recommend reading crypto.py to familiarize yourself with the
    # code even further.
    #
    # YOU CAN COMFORTABLY DELETE ALL OF THE BELOW CODE.
    #

    print(f"Forging message that includes {injection} within {message}")

    # you can...

    # combine bytes together,
    forgery = message + injection

    # make queries to the oracle,
    tag = oracle.query(message)

    # craft new message/tag based on those queries,
    hasher = crypto.Sha1()
    hasher.update(b"hello, world!")
    new_tag = hasher.hexdigest()
    hasher.clear()

    # use sha1 internals directly, e.g.
    #  - hasher.sha1()
    #  - hasher.pad_message()
    #  - hasher.create_padding()
    manual_tag = hasher.sha1(b"hello, world!",
                             extra_length=0, initial_state=None)
    assert new_tag == manual_tag

    # or check the validity of novel tags.
    assert oracle.verify(message, tag)

    return b"", ""
