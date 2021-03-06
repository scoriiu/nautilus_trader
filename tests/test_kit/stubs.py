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

from datetime import datetime
from datetime import timedelta

import pytz

from nautilus_trader.common.factories import OrderFactory
from nautilus_trader.core.decimal import Decimal64
from nautilus_trader.core.uuid import uuid4
from nautilus_trader.model.bar import Bar
from nautilus_trader.model.bar import BarSpecification
from nautilus_trader.model.bar import BarType
from nautilus_trader.model.enums import AccountType
from nautilus_trader.model.enums import BarAggregation
from nautilus_trader.model.enums import Currency
from nautilus_trader.model.enums import OrderSide
from nautilus_trader.model.enums import PriceType
from nautilus_trader.model.events import AccountStateEvent
from nautilus_trader.model.events import OrderAccepted
from nautilus_trader.model.events import OrderCancelled
from nautilus_trader.model.events import OrderExpired
from nautilus_trader.model.events import OrderFilled
from nautilus_trader.model.events import OrderRejected
from nautilus_trader.model.events import OrderSubmitted
from nautilus_trader.model.events import OrderWorking
from nautilus_trader.model.events import PositionClosed
from nautilus_trader.model.events import PositionModified
from nautilus_trader.model.events import PositionOpened
from nautilus_trader.model.generators import PositionIdGenerator
from nautilus_trader.model.identifiers import AccountId
from nautilus_trader.model.identifiers import ExecutionId
from nautilus_trader.model.identifiers import IdTag
from nautilus_trader.model.identifiers import OrderIdBroker
from nautilus_trader.model.identifiers import PositionIdBroker
from nautilus_trader.model.identifiers import StrategyId
from nautilus_trader.model.identifiers import Symbol
from nautilus_trader.model.identifiers import TraderId
from nautilus_trader.model.identifiers import Venue
from nautilus_trader.model.instrument import ForexInstrument
from nautilus_trader.model.objects import Money
from nautilus_trader.model.objects import Price
from nautilus_trader.model.objects import Quantity
from nautilus_trader.model.position import Position
from nautilus_trader.model.tick import QuoteTick

# Unix epoch is the UTC time at 00:00:00 on 1/1/1970
UNIX_EPOCH = datetime(1970, 1, 1, 0, 0, 0, 0, tzinfo=pytz.utc)


class TestStubs:

    @staticmethod
    def symbol_audusd_fxcm() -> Symbol:
        return Symbol("AUD/USD", Venue('FXCM'))

    @staticmethod
    def symbol_gbpusd_fxcm() -> Symbol:
        return Symbol("GBP/USD", Venue('FXCM'))

    @staticmethod
    def symbol_usdjpy_fxcm() -> Symbol:
        return Symbol("USD/JPY", Venue('FXCM'))

    @staticmethod
    def instrument_gbpusd() -> ForexInstrument:
        return ForexInstrument(
            Symbol("GBP/USD", Venue('FXCM')),
            price_precision=5,
            size_precision=0,
            min_stop_distance_entry=0,
            min_limit_distance_entry=0,
            min_stop_distance=0,
            min_limit_distance=0,
            tick_size=Price(0.00001, 5),
            round_lot_size=Quantity(1000),
            min_trade_size=Quantity(1),
            max_trade_size=Quantity(50000000),
            rollover_interest_buy=Decimal64(0),
            rollover_interest_sell=Decimal64(0),
            timestamp=UNIX_EPOCH)

    @staticmethod
    def instrument_usdjpy() -> ForexInstrument:
        return ForexInstrument(
            Symbol("USD/JPY", Venue('FXCM')),
            price_precision=3,
            size_precision=0,
            min_stop_distance_entry=0,
            min_limit_distance_entry=0,
            min_stop_distance=0,
            min_limit_distance=0,
            tick_size=Price(0.001, 3),
            round_lot_size=Quantity(1000),
            min_trade_size=Quantity(1),
            max_trade_size=Quantity(50000000),
            rollover_interest_buy=Decimal64(0),
            rollover_interest_sell=Decimal64(0),
            timestamp=UNIX_EPOCH)

    @staticmethod
    def bar_spec_1min_bid() -> BarSpecification:
        return BarSpecification(1, BarAggregation.MINUTE, PriceType.BID)

    @staticmethod
    def bar_spec_1min_ask() -> BarSpecification:
        return BarSpecification(1, BarAggregation.MINUTE, PriceType.ASK)

    @staticmethod
    def bar_spec_1min_mid() -> BarSpecification:
        return BarSpecification(1, BarAggregation.MINUTE, PriceType.MID)

    @staticmethod
    def bar_spec_1sec_mid() -> BarSpecification:
        return BarSpecification(1, BarAggregation.SECOND, PriceType.MID)

    @staticmethod
    def bartype_audusd_1min_bid() -> BarType:
        return BarType(TestStubs.symbol_audusd_fxcm(), TestStubs.bar_spec_1min_bid())

    @staticmethod
    def bartype_audusd_1min_ask() -> BarType:
        return BarType(TestStubs.symbol_audusd_fxcm(), TestStubs.bar_spec_1min_ask())

    @staticmethod
    def bartype_gbpusd_1min_bid() -> BarType:
        return BarType(TestStubs.symbol_gbpusd_fxcm(), TestStubs.bar_spec_1min_bid())

    @staticmethod
    def bartype_gbpusd_1min_ask() -> BarType:
        return BarType(TestStubs.symbol_gbpusd_fxcm(), TestStubs.bar_spec_1min_ask())

    @staticmethod
    def bartype_gbpusd_1sec_mid() -> BarType:
        return BarType(TestStubs.symbol_gbpusd_fxcm(), TestStubs.bar_spec_1sec_mid())

    @staticmethod
    def bartype_usdjpy_1min_bid() -> BarType:
        return BarType(TestStubs.symbol_usdjpy_fxcm(), TestStubs.bar_spec_1min_bid())

    @staticmethod
    def bartype_usdjpy_1min_ask() -> BarType:
        return BarType(TestStubs.symbol_usdjpy_fxcm(), TestStubs.bar_spec_1min_ask())

    @staticmethod
    def bar_5decimal() -> Bar:
        return Bar(
            Price(1.00002, 5),
            Price(1.00004, 5),
            Price(1.00001, 5),
            Price(1.00003, 5),
            Quantity(100000),
            UNIX_EPOCH)

    @staticmethod
    def bar_3decimal() -> Bar:
        return Bar(
            Price(90.002, 3),
            Price(90.004, 3),
            Price(90.001, 3),
            Price(90.003, 3),
            Quantity(100000),
            UNIX_EPOCH)

    @staticmethod
    def quote_tick_3decimal(symbol) -> QuoteTick:
        return QuoteTick(
            symbol,
            Price(90.002, 3),
            Price(90.003, 3),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

    @staticmethod
    def trader_id() -> TraderId:
        return TraderId("TESTER", "000")

    @staticmethod
    def account_id() -> AccountId:
        return AccountId("NAUTILUS", "000", AccountType.SIMULATED)

    @staticmethod
    def account_event(account_id=None) -> AccountStateEvent:
        if account_id is None:
            account_id = TestStubs.account_id()

        return AccountStateEvent(
            account_id,
            Currency.USD,
            Money(1000000, Currency.USD),
            Money(1000000, Currency.USD),
            Money(0, Currency.USD),
            Money(0, Currency.USD),
            Money(0, Currency.USD),
            Decimal64(0),
            'N',
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_order_submitted(order) -> OrderSubmitted:
        return OrderSubmitted(
            TestStubs.account_id(),
            order.id,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_order_accepted(order) -> OrderAccepted:
        return OrderAccepted(
            TestStubs.account_id(),
            order.id,
            OrderIdBroker(order.id.value.replace('O', 'B')),
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_order_rejected(order) -> OrderRejected:
        return OrderRejected(
            TestStubs.account_id(),
            order.id,
            UNIX_EPOCH,
            "ORDER_REJECTED",
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_order_filled(order, fill_price=None) -> OrderFilled:
        if fill_price is None:
            fill_price = Price(1.00000, 5)

        return OrderFilled(
            TestStubs.account_id(),
            order.id,
            ExecutionId(order.id.value.replace('O', 'E')),
            PositionIdBroker(order.id.value.replace('P', 'T')),
            order.symbol,
            order.side,
            order.quantity,
            order.price if fill_price is None else fill_price,
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_order_working(order, working_price=None) -> OrderWorking:
        if working_price is None:
            working_price = Price(1.00000, 5)

        return OrderWorking(
            TestStubs.account_id(),
            order.id,
            OrderIdBroker(order.id.value.replace('O', 'B')),
            order.symbol,
            order.side,
            order.type,
            order.quantity,
            order.price if working_price is None else working_price,
            order.time_in_force,
            order.expire_time,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_order_cancelled(order) -> OrderCancelled:
        return OrderCancelled(
            TestStubs.account_id(),
            order.id,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_order_expired(order) -> OrderExpired:
        return OrderExpired(
            TestStubs.account_id(),
            order.id,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_position_opened(position) -> PositionOpened:
        return PositionOpened(
            position,
            StrategyId("SCALPER", "001"),
            position.last_event(),
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_position_modified(position) -> PositionModified:
        return PositionModified(
            position,
            StrategyId("SCALPER", "001"),
            position.last_event(),
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def event_position_closed(position) -> PositionClosed:
        return PositionClosed(
            position,
            StrategyId("SCALPER", "001"),
            position.last_event(),
            uuid4(),
            UNIX_EPOCH)

    @staticmethod
    def position(number=1, entry_price=None) -> Position:
        if entry_price is None:
            entry_price = Price(1.00000, 5)

        generator = PositionIdGenerator(
            id_tag_trader=IdTag("001"),
            id_tag_strategy=IdTag("001"))

        for _i in range(number - 1):
            generator.generate()

        order_factory = OrderFactory(
            id_tag_trader=IdTag("001"),
            id_tag_strategy=IdTag("001"))

        order = order_factory.market(
            TestStubs.symbol_audusd_fxcm(),
            OrderSide.BUY,
            Quantity(100000))

        order_filled = TestStubs.event_order_filled(order, entry_price)

        position_id = generator.generate()
        position = Position(position_id=position_id, event=order_filled)

        return position

    @staticmethod
    def position_which_is_closed(number=1, close_price=None) -> Position:
        if close_price is None:
            close_price = Price(1.0001, 5)

        position = TestStubs.position(number=number)

        order_factory = OrderFactory(
            id_tag_trader=IdTag("001"),
            id_tag_strategy=IdTag("001"))

        order = order_factory.market(
            TestStubs.symbol_audusd_fxcm(),
            OrderSide.SELL,
            Quantity(100000))

        order_filled = OrderFilled(
            TestStubs.account_id(),
            order.id,
            ExecutionId(order.id.value.replace('O', 'E')),
            PositionIdBroker(position.id.value.replace('P', 'T')),
            order.symbol,
            order.side,
            order.quantity,
            close_price,
            Currency.USD,
            UNIX_EPOCH + timedelta(minutes=5),
            uuid4(),
            UNIX_EPOCH + timedelta(minutes=5))

        position.apply(order_filled)

        return position
