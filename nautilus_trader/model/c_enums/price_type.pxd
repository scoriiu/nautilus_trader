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


cpdef enum PriceType:
    UNDEFINED = 0,  # Invalid value
    BID = 1,
    ASK = 2,
    MID = 3,
    LAST = 4


cdef inline str price_type_to_string(int value):
    if value == 1:
        return 'BID'
    elif value == 2:
        return 'ASK'
    elif value == 3:
        return 'MID'
    elif value == 4:
        return 'LAST'
    else:
        return 'UNDEFINED'


cdef inline PriceType price_type_from_string(str value):
    if value == 'BID':
        return PriceType.BID
    elif value == 'ASK':
        return PriceType.ASK
    elif value == 'MID':
        return PriceType.MID
    elif value == 'LAST':
        return PriceType.LAST
    else:
        return PriceType.UNDEFINED
