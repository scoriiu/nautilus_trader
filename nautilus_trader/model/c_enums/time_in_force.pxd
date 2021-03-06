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


cpdef enum TimeInForce:
    UNDEFINED = 0,  # Invalid value
    DAY = 1,
    GTC = 2,
    IOC = 3,
    FOC = 4,
    GTD = 5


cdef inline str time_in_force_to_string(int value):
    if value == 1:
        return 'DAY'
    elif value == 2:
        return 'GTC'
    elif value == 3:
        return 'IOC'
    elif value == 4:
        return 'FOC'
    elif value == 5:
        return 'GTD'
    else:
        return 'UNDEFINED'


cdef inline TimeInForce time_in_force_from_string(str value):
    if value == 'DAY':
        return TimeInForce.DAY
    elif value == 'GTC':
        return TimeInForce.GTC
    elif value == 'IOC':
        return TimeInForce.IOC
    elif value == 'FOC':
        return TimeInForce.FOC
    elif value == 'GTD':
        return TimeInForce.GTD
    else:
        return TimeInForce.UNDEFINED
