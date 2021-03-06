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

from nautilus_trader.model.identifiers cimport Symbol
from nautilus_trader.model.tick cimport QuoteTick
from nautilus_trader.indicators.base.indicator cimport Indicator


cdef class SpreadAnalyzer(Indicator):
    cdef readonly Symbol symbol
    cdef readonly int capacity
    cdef readonly double current_spread
    cdef readonly double average_spread

    cdef object _spreads

    cpdef void handle_quote_tick(self, QuoteTick tick) except *
    cpdef void reset(self)
