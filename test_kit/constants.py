#!/usr/bin/env python3
# -------------------------------------------------------------------------------------------------
# <copyright file="constants.py" company="Invariance Pte">
#  Copyright (C) 2018 Invariance Pte. All rights reserved.
#  The use of this source code is governed by the license as found in the LICENSE.md file.
#  http://www.invariance.com
# </copyright>
# -------------------------------------------------------------------------------------------------

import datetime
import pytz
import sys

# Epsilon is a positive infinitesimal quantity approaching zero.
EPSILON = sys.float_info.epsilon

# Unix epoch is the UTC time at 00:00:00 on 1/1/1970.
UNIX_EPOCH = datetime.datetime(1970, 1, 1, 0, 0, 0, 0, pytz.UTC)


class TestConstants(object):

    @staticmethod
    def unix_epoch(offset_mins: int=0) -> datetime.datetime:
        """
        Generate a datetime based on the given offset from Unix epoch time.

        Unix time (also known as POSIX time or epoch time) is a system for
        describing instants in time, defined as the number of seconds that have
        elapsed since 00:00:00 Coordinated Universal Time (UTC), on Thursday,
        1 January 1970, minus the number of leap seconds which have taken place
        since then.

        :return: The unix epoch datetime.
        """
        return UNIX_EPOCH + datetime.timedelta(minutes=offset_mins)
