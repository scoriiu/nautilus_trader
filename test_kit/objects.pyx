#!/usr/bin/env python3
# -------------------------------------------------------------------------------------------------
# <copyright file="objects.pyx" company="Invariance Pte">
#  Copyright (C) 2018-2019 Invariance Pte. All rights reserved.
#  The use of this source code is governed by the license as found in the LICENSE.md file.
#  http://www.invariance.com
# </copyright>
# -------------------------------------------------------------------------------------------------

# cython: language_level=3, boundscheck=False


cdef class ObjectStorer:
    """"
    A test class which stores the given objects.
    """

    def __init__(self):
        """
        Initializes a new instance of the ObjectStorer class.
        """
        self._store = list()

    cpdef list get_store(self):
        """"
        return: The internal object store.
        """
        return self._store

    cpdef void store(self, object obj):
        """"
        Store the given object.
        """
        print(f"Storing {obj}")
        self.count += 1
        self._store.append(obj)

    cpdef void store_2(self, object obj1, object obj2):
        """"
        Store the given objects as a tuple.
        """
        print(f"Storing {(obj1, obj2)}")
        self.count += 1
        self._store.append((obj1, obj2))