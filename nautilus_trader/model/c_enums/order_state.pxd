# -------------------------------------------------------------------------------------------------
#  Copyright (C) 2015-2020 Nautech Systems Pty Ltd. All rights reserved.
#  https://nautechsystems.io
#
#  Licensed under the GNU Lesser General Public License Version 3.0 (the "License");
#  You may not use this file except in compliance with the License.
#  You may obtain a copy of the License at https://www.gnu.org/licenses/lgpl-3.0.en.html
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# -------------------------------------------------------------------------------------------------


cpdef enum OrderState:
    UNDEFINED = 0,  # Invalid value
    INITIALIZED = 1,
    INVALID = 2,
    DENIED = 3,
    SUBMITTED = 4,
    ACCEPTED = 5,
    REJECTED = 6,
    WORKING = 7,
    CANCELLED = 8,
    EXPIRED = 9,
    PARTIALLY_FILLED = 10,
    FILLED = 11,


cdef inline str order_state_to_string(int value):
    if value == 1:
        return 'INITIALIZED'
    elif value == 2:
        return 'INVALID'
    elif value == 3:
        return 'DENIED'
    elif value == 4:
        return 'SUBMITTED'
    elif value == 5:
        return 'ACCEPTED'
    elif value == 6:
        return 'REJECTED'
    elif value == 7:
        return 'WORKING'
    elif value == 8:
        return 'CANCELLED'
    elif value == 9:
        return 'EXPIRED'
    elif value == 10:
        return 'PARTIALLY_FILLED'
    elif value == 11:
        return 'FILLED'
    else:
        return 'UNDEFINED'


cdef inline OrderState order_state_from_string(str value):
    if value == 'INITIALIZED':
        return OrderState.INITIALIZED
    elif value == 'INVALID':
        return OrderState.INVALID
    elif value == 'DENIED':
        return OrderState.DENIED
    elif value == 'SUBMITTED':
        return OrderState.SUBMITTED
    elif value == 'ACCEPTED':
        return OrderState.ACCEPTED
    elif value == 'REJECTED':
        return OrderState.REJECTED
    elif value == 'WORKING':
        return OrderState.WORKING
    elif value == 'CANCELLED':
        return OrderState.CANCELLED
    elif value == 'EXPIRED':
        return OrderState.EXPIRED
    elif value == 'PARTIALLY_FILLED':
        return OrderState.PARTIALLY_FILLED
    elif value == 'FILLED':
        return OrderState.FILLED
    else:
        return OrderState.UNDEFINED
