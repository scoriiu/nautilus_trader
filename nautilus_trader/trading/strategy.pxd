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

from nautilus_trader.common.account cimport Account
from nautilus_trader.common.clock cimport Clock
from nautilus_trader.common.data cimport DataClient
from nautilus_trader.common.execution cimport ExecutionEngine
from nautilus_trader.common.factories cimport OrderFactory
from nautilus_trader.common.logging cimport Logger
from nautilus_trader.common.logging cimport LoggerAdapter
from nautilus_trader.common.portfolio cimport Portfolio
from nautilus_trader.common.uuid cimport UUIDFactory
from nautilus_trader.core.fsm cimport FiniteStateMachine
from nautilus_trader.indicators.base.indicator cimport Indicator
from nautilus_trader.model.bar cimport Bar
from nautilus_trader.model.bar cimport BarType
from nautilus_trader.model.c_enums.component_state cimport ComponentState
from nautilus_trader.model.c_enums.currency cimport Currency
from nautilus_trader.model.c_enums.market_position cimport MarketPosition
from nautilus_trader.model.c_enums.order_side cimport OrderSide
from nautilus_trader.model.c_enums.price_type cimport PriceType
from nautilus_trader.model.events cimport Event
from nautilus_trader.model.events cimport OrderRejected
from nautilus_trader.model.generators cimport PositionIdGenerator
from nautilus_trader.model.identifiers cimport OrderId
from nautilus_trader.model.identifiers cimport PositionId
from nautilus_trader.model.identifiers cimport StrategyId
from nautilus_trader.model.identifiers cimport Symbol
from nautilus_trader.model.identifiers cimport TraderId
from nautilus_trader.model.instrument cimport Instrument
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity
from nautilus_trader.model.order cimport BracketOrder
from nautilus_trader.model.order cimport Order
from nautilus_trader.model.order cimport PassiveOrder
from nautilus_trader.model.position cimport Position
from nautilus_trader.model.tick cimport QuoteTick
from nautilus_trader.model.tick cimport TradeTick


cdef class TradingStrategy:
    cdef readonly Clock clock
    cdef readonly UUIDFactory uuid_factory
    cdef readonly LoggerAdapter log

    cdef readonly StrategyId id
    cdef readonly TraderId trader_id

    cdef readonly bint flatten_on_stop
    cdef readonly bint flatten_on_reject
    cdef readonly bint cancel_all_orders_on_stop
    cdef readonly bint reraise_exceptions

    cdef readonly OrderFactory order_factory
    cdef readonly PositionIdGenerator position_id_generator
    cdef set _flattening_ids
    cdef set _stop_loss_ids
    cdef set _take_profit_ids

    cdef list _indicators
    cdef dict _indicators_for_quotes
    cdef dict _indicators_for_trades
    cdef dict _indicators_for_bars

    cdef DataClient _data
    cdef ExecutionEngine _exec

    cdef FiniteStateMachine _fsm

    cpdef bint equals(self, TradingStrategy other)
    cpdef ComponentState state(self)

# -- ABSTRACT METHODS -----------------------------------------------------------------------------#
    cpdef void on_start(self) except *
    cpdef void on_quote_tick(self, QuoteTick tick) except *
    cpdef void on_trade_tick(self, TradeTick tick) except *
    cpdef void on_bar(self, BarType bar_type, Bar bar) except *
    cpdef void on_data(self, object data) except *
    cpdef void on_event(self, Event event) except *
    cpdef void on_stop(self) except *
    cpdef void on_resume(self) except *
    cpdef void on_reset(self) except *
    cpdef dict on_save(self)
    cpdef void on_load(self, dict state) except *
    cpdef void on_dispose(self) except *

# -- REGISTRATION METHODS -------------------------------------------------------------------------#
    cpdef void register_trader(self, TraderId trader_id, Clock clock, UUIDFactory uuid_factory, Logger logger) except *
    cpdef void register_data_client(self, DataClient client) except *
    cpdef void register_execution_engine(self, ExecutionEngine engine) except *
    cpdef void register_indicator_for_quote_ticks(self, Symbol symbol, Indicator indicator) except *
    cpdef void register_indicator_for_trade_ticks(self, Symbol symbol, Indicator indicator) except *
    cpdef void register_indicator_for_bars(self, BarType bar_type, Indicator indicator) except *
    cpdef void register_stop_loss(self, PassiveOrder order)
    cpdef void register_take_profit(self, PassiveOrder order)

# -- HANDLER METHODS ------------------------------------------------------------------------------#
    cpdef void handle_quote_tick(self, QuoteTick tick, bint is_historical=*) except *
    cpdef void handle_quote_ticks(self, list ticks) except *
    cpdef void handle_trade_tick(self, TradeTick tick, bint is_historical=*) except *
    cpdef void handle_trade_ticks(self, list ticks) except *
    cpdef void handle_bar(self, BarType bar_type, Bar bar, bint is_historical=*) except *
    cpdef void handle_bars(self, BarType bar_type, list bars) except *
    cpdef void handle_data(self, object data) except *
    cpdef void handle_event(self, Event event) except *

# -- DATA METHODS ---------------------------------------------------------------------------------#
    cpdef list instrument_symbols(self)
    cpdef void get_quote_ticks(self, Symbol symbol) except *
    cpdef void get_trade_ticks(self, Symbol symbol) except *
    cpdef void get_bars(self, BarType bar_type) except *
    cpdef Instrument get_instrument(self, Symbol symbol)
    cpdef dict get_instruments(self)
    cpdef void subscribe_quote_ticks(self, Symbol symbol) except *
    cpdef void subscribe_trade_ticks(self, Symbol symbol) except *
    cpdef void subscribe_bars(self, BarType bar_type) except *
    cpdef void subscribe_instrument(self, Symbol symbol) except *
    cpdef void unsubscribe_quote_ticks(self, Symbol symbol) except *
    cpdef void unsubscribe_trade_ticks(self, Symbol symbol) except *
    cpdef void unsubscribe_bars(self, BarType bar_type) except *
    cpdef void unsubscribe_instrument(self, Symbol symbol) except *
    cpdef bint has_quote_ticks(self, Symbol symbol)
    cpdef bint has_trade_ticks(self, Symbol symbol)
    cpdef bint has_bars(self, BarType bar_type)
    cpdef int quote_tick_count(self, Symbol symbol)
    cpdef int trade_tick_count(self, Symbol symbol)
    cpdef int bar_count(self, BarType bar_type)
    cpdef list quote_ticks(self, Symbol symbol)
    cpdef list trade_ticks(self, Symbol symbol)
    cpdef list bars(self, BarType bar_type)
    cpdef QuoteTick quote_tick(self, Symbol symbol, int index=*)
    cpdef TradeTick trade_tick(self, Symbol symbol, int index=*)
    cpdef Bar bar(self, BarType bar_type, int index=*)

# -- INDICATOR METHODS ----------------------------------------------------------------------------#
    cpdef readonly list registered_indicators(self)
    cpdef readonly bint indicators_initialized(self)

# -- MANAGEMENT METHODS ---------------------------------------------------------------------------#
    cpdef Account account(self)
    cpdef Portfolio portfolio(self)
    cpdef OrderSide get_opposite_side(self, OrderSide side)
    cpdef OrderSide get_flatten_side(self, MarketPosition market_position)
    cpdef double get_exchange_rate(
        self,
        Currency from_currency,
        Currency to_currency,
        PriceType price_type=*)
    cpdef double get_exchange_rate_for_account(
        self,
        Currency quote_currency,
        PriceType price_type=*)
    cpdef Order order(self, OrderId order_id)
    cpdef dict orders(self)
    cpdef dict orders_working(self)
    cpdef set stop_loss_ids(self)
    cpdef set take_profit_ids(self)
    cpdef dict orders_completed(self)
    cpdef Position position(self, PositionId position_id)
    cpdef Position position_for_order(self, OrderId order_id)
    cpdef dict positions(self)
    cpdef dict positions_open(self)
    cpdef dict positions_closed(self)
    cpdef bint position_exists(self, PositionId position_id)
    cpdef bint order_exists(self, OrderId order_id)
    cpdef bint is_stop_loss(self, OrderId order_id)
    cpdef bint is_take_profit(self, OrderId order_id)
    cpdef bint is_order_working(self, OrderId order_id)
    cpdef bint is_order_completed(self, OrderId order_id)
    cpdef bint is_position_open(self, PositionId position_id)
    cpdef bint is_position_closed(self, PositionId position_id)
    cpdef bint is_flat(self)
    cpdef int count_orders_working(self)
    cpdef int count_orders_completed(self)
    cpdef int count_orders_total(self)
    cpdef int count_positions_open(self)
    cpdef int count_positions_closed(self)
    cpdef int count_positions_total(self)

# -- COMMANDS -------------------------------------------------------------------------------------#
    cpdef void start(self) except *
    cpdef void stop(self) except *
    cpdef void resume(self) except *
    cpdef void reset(self) except *
    cpdef void dispose(self) except *
    cpdef dict save(self)
    cpdef void load(self, dict state) except *
    cpdef void account_inquiry(self) except *
    cpdef void submit_order(self, Order order, PositionId position_id) except *
    cpdef void submit_bracket_order(self, BracketOrder bracket_order, PositionId position_id, bint register=*) except *
    cpdef void modify_order(self, Order order, Quantity new_quantity=*, Price new_price=*) except *
    cpdef void cancel_order(self, Order order) except *
    cpdef void cancel_all_orders(self) except *
    cpdef void flatten_position(self, PositionId position_id) except *
    cpdef void flatten_all_positions(self) except *

    cdef void _flatten_on_reject(self, OrderRejected event) except *
