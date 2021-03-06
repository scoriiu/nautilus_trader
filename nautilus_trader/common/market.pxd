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

from cpython.datetime cimport datetime
from cpython.datetime cimport timedelta

from nautilus_trader.common.clock cimport Clock
from nautilus_trader.common.data cimport DataClient
from nautilus_trader.common.handlers cimport BarHandler
from nautilus_trader.common.logging cimport LoggerAdapter
from nautilus_trader.common.timer cimport TimeEvent
from nautilus_trader.model.bar cimport Bar
from nautilus_trader.model.bar cimport BarSpecification
from nautilus_trader.model.bar cimport BarType
from nautilus_trader.model.c_enums.bar_aggregation cimport BarAggregation
from nautilus_trader.model.instrument cimport Instrument
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity
from nautilus_trader.model.tick cimport QuoteTick


cdef class TickDataWrangler:
    cdef object _data_ticks
    cdef dict _data_bars_ask
    cdef dict _data_bars_bid

    cdef readonly Instrument instrument
    cdef readonly tick_data
    cdef readonly BarAggregation resolution

    cpdef void build(self, int symbol_indexer) except *
    cpdef QuoteTick _build_tick_from_values_with_sizes(self, double[:] values, datetime timestamp)
    cpdef QuoteTick _build_tick_from_values(self, double[:] values, datetime timestamp)


cdef class BarDataWrangler:
    cdef int _precision
    cdef int _volume_multiple
    cdef object _data

    cpdef list build_bars_all(self)
    cpdef list build_bars_from(self, int index=*)
    cpdef list build_bars_range(self, int start=*, int end=*)
    cpdef Bar _build_bar(self, double[:] values, datetime timestamp)


cdef class BarBuilder:
    cdef readonly BarSpecification bar_spec
    cdef readonly datetime last_update
    cdef readonly bint initialized
    cdef readonly bint use_previous_close
    cdef readonly int count

    cdef Price _last_close
    cdef Price _open
    cdef Price _high
    cdef Price _low
    cdef Price _close
    cdef Quantity _volume

    cpdef void update(self, QuoteTick tick) except *
    cpdef Bar build(self, datetime close_time=*)
    cdef void _reset(self) except *
    cdef Price _get_price(self, QuoteTick tick)
    cdef Quantity _get_volume(self, QuoteTick tick)


cdef class BarAggregator:
    cdef LoggerAdapter _log
    cdef DataClient _client
    cdef BarHandler _handler
    cdef BarBuilder _builder

    cdef readonly BarType bar_type

    cpdef void update(self, QuoteTick tick) except *
    cpdef void _handle_bar(self, Bar bar) except *


cdef class TickBarAggregator(BarAggregator):
    cdef int step


cdef class TimeBarAggregator(BarAggregator):
    cdef Clock _clock

    cdef readonly timedelta interval
    cdef readonly datetime next_close

    cpdef datetime get_start_time(self)
    cpdef void stop(self) except *
    cdef timedelta _get_interval(self)
    cpdef void _set_build_timer(self) except *
    cpdef void _build_bar(self, datetime at_time) except *
    cpdef void _build_event(self, TimeEvent event) except *
