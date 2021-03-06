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
import unittest

import pytz

from nautilus_trader.backtest.clock import TestClock
from nautilus_trader.common.factories import OrderFactory
from nautilus_trader.core.uuid import uuid4
from nautilus_trader.model.enums import Currency
from nautilus_trader.model.enums import MarketPosition
from nautilus_trader.model.enums import OrderSide
from nautilus_trader.model.events import OrderFilled
from nautilus_trader.model.events import OrderPartiallyFilled
from nautilus_trader.model.identifiers import ExecutionId
from nautilus_trader.model.identifiers import IdTag
from nautilus_trader.model.identifiers import OrderId
from nautilus_trader.model.identifiers import PositionId
from nautilus_trader.model.identifiers import PositionIdBroker
from nautilus_trader.model.objects import Money
from nautilus_trader.model.objects import Price
from nautilus_trader.model.objects import Quantity
from nautilus_trader.model.position import Position
from nautilus_trader.model.tick import QuoteTick
from tests.test_kit.stubs import TestStubs
from tests.test_kit.stubs import UNIX_EPOCH

AUDUSD_FXCM = TestStubs.symbol_audusd_fxcm()
GBPUSD_FXCM = TestStubs.symbol_gbpusd_fxcm()


class PositionTests(unittest.TestCase):

    def setUp(self):
        # Fixture Setup
        self.account_id = TestStubs.account_id()
        self.order_factory = OrderFactory(
            id_tag_trader=IdTag("001"),
            id_tag_strategy=IdTag("001"),
            clock=TestClock())
        print("\n")

    def test_position_filled_with_buy_order_returns_expected_attributes(self):
        # Arrange
        order = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.BUY,
            Quantity(100000))

        order_filled = OrderFilled(
            self.account_id,
            order.id,
            ExecutionId("E123456"),
            PositionIdBroker("T123456"),
            order.symbol,
            order.side,
            order.quantity,
            Price(1.00001, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        last = QuoteTick(
            AUDUSD_FXCM,
            Price(1.00050, 5),
            Price(1.00048, 5),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

        # Act
        position = Position(PositionId("P-123456"), order_filled)

        # Assert
        self.assertEqual(OrderId("O-19700101-000000-001-001-1"), position.from_order_id)
        self.assertEqual(Quantity(100000), position.quantity)
        self.assertEqual(Quantity(100000), position.peak_quantity)
        self.assertEqual(OrderSide.BUY, position.entry_direction)
        self.assertEqual(MarketPosition.LONG, position.market_position)
        self.assertEqual(UNIX_EPOCH, position.opened_time)
        self.assertIsNone(position.open_duration)
        self.assertEqual(1.00001, position.average_open_price)
        self.assertEqual(1, position.event_count())
        self.assertEqual([order.id], position.get_order_ids())
        self.assertEqual([ExecutionId("E123456")], position.get_execution_ids())
        self.assertEqual(ExecutionId("E123456"), position.last_execution_id())
        self.assertEqual(PositionIdBroker("T123456"), position.id_broker)
        self.assertTrue(position.is_long())
        self.assertFalse(position.is_short())
        self.assertFalse(position.is_closed())
        self.assertEqual(0.0, position.realized_points)
        self.assertEqual(0.0, position.realized_return)
        self.assertEqual(Money(0, Currency.USD), position.realized_pnl)
        self.assertEqual(0.0004899999999998794, position.unrealized_points(last))
        self.assertEqual(0.0004899951000488789, position.unrealized_return(last))
        self.assertEqual(Money(49.00, Currency.USD), position.unrealized_pnl(last))
        self.assertEqual(0.0004899999999998794, position.total_points(last))
        self.assertEqual(0.0004899951000488789, position.total_return(last))
        self.assertEqual(Money(49.00, Currency.USD), position.total_pnl(last))

    def test_position_filled_with_sell_order_returns_expected_attributes(self):
        # Arrange
        order = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.SELL,
            Quantity(100000))

        order_filled = OrderFilled(
            self.account_id,
            order.id,
            ExecutionId("E123456"),
            PositionIdBroker("T123456"),
            order.symbol,
            order.side,
            order.quantity,
            Price(1.00001, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        last = QuoteTick(
            AUDUSD_FXCM,
            Price(1.00050, 5),
            Price(1.00048, 5),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

        # Act
        position = Position(PositionId("P-123456"), order_filled)

        # Assert
        self.assertEqual(Quantity(100000), position.quantity)
        self.assertEqual(Quantity(100000), position.peak_quantity)
        self.assertEqual(MarketPosition.SHORT, position.market_position)
        self.assertEqual(UNIX_EPOCH, position.opened_time)
        self.assertEqual(1.00001, position.average_open_price)
        self.assertEqual(1, position.event_count())
        self.assertEqual(ExecutionId("E123456"), position.last_execution_id())
        self.assertEqual(PositionIdBroker("T123456"), position.id_broker)
        self.assertFalse(position.is_long())
        self.assertTrue(position.is_short())
        self.assertFalse(position.is_closed())
        self.assertEqual(0.0, position.realized_points)
        self.assertEqual(0.0, position.realized_return)
        self.assertEqual(Money(0, Currency.USD), position.realized_pnl)
        self.assertEqual(-0.00046999999999997044, position.unrealized_points(last))
        self.assertEqual(-0.0004699953000469699, position.unrealized_return(last))
        self.assertEqual(Money(-47.00, Currency.USD), position.unrealized_pnl(last))
        self.assertEqual(-0.00046999999999997044, position.total_points(last))
        self.assertEqual(-0.0004699953000469699, position.total_return(last))
        self.assertEqual(Money(-47.00, Currency.USD), position.total_pnl(last))

    def test_position_partial_fills_with_buy_order_returns_expected_attributes(self):
        # Arrange
        order = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.BUY,
            Quantity(100000))

        order_partially_filled = OrderPartiallyFilled(
            self.account_id,
            order.id,
            ExecutionId("E123456"),
            PositionIdBroker("T123456"),
            order.symbol,
            order.side,
            Quantity(50000),
            Quantity(50000),
            Price(1.00001, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        last = QuoteTick(
            AUDUSD_FXCM,
            Price(1.00050, 5),
            Price(1.00048, 5),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

        position = Position(PositionId("P-123456"), order_partially_filled)

        # Act
        # Assert
        self.assertEqual(Quantity(50000), position.quantity)
        self.assertEqual(Quantity(50000), position.peak_quantity)
        self.assertEqual(MarketPosition.LONG, position.market_position)
        self.assertEqual(UNIX_EPOCH, position.opened_time)
        self.assertEqual(1.00001, position.average_open_price)
        self.assertEqual(1, position.event_count())
        self.assertEqual(ExecutionId("E123456"), position.last_execution_id())
        self.assertEqual(PositionIdBroker("T123456"), position.id_broker)
        self.assertTrue(position.is_long())
        self.assertFalse(position.is_short())
        self.assertFalse(position.is_closed())
        self.assertEqual(0.0, position.realized_points)
        self.assertEqual(0.0, position.realized_return)
        self.assertEqual(Money(0, Currency.USD), position.realized_pnl)
        self.assertEqual(0.0004899999999998794, position.unrealized_points(last))
        self.assertEqual(0.0004899951000488789, position.unrealized_return(last))
        self.assertEqual(Money(24.50, Currency.USD), position.unrealized_pnl(last))
        self.assertEqual(0.0004899999999998794, position.total_points(last))
        self.assertEqual(0.0004899951000488789, position.total_return(last))
        self.assertEqual(Money(24.50, Currency.USD), position.total_pnl(last))

    def test_position_partial_fills_with_sell_order_returns_expected_attributes(self):
        # Arrange
        order = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.SELL,
            Quantity(100000))

        order_partially_filled1 = OrderPartiallyFilled(
            self.account_id,
            order.id,
            ExecutionId("E1"),
            PositionIdBroker("T123456"),
            order.symbol,
            order.side,
            Quantity(50000),
            Quantity(50000),
            Price(1.00001, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        order_partially_filled2 = OrderPartiallyFilled(
            self.account_id,
            order.id,
            ExecutionId("E2"),
            PositionIdBroker("T123456"),
            order.symbol,
            order.side,
            Quantity(100000),
            Quantity(),
            Price(1.00002, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        position = Position(PositionId("P-123456"), order_partially_filled1)

        last = QuoteTick(
            AUDUSD_FXCM,
            Price(1.00050, 5),
            Price(1.00048, 5),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

        # Act
        position.apply(order_partially_filled2)

        # Assert
        self.assertEqual(Quantity(100000), position.quantity)
        self.assertEqual(MarketPosition.SHORT, position.market_position)
        self.assertEqual(UNIX_EPOCH, position.opened_time)
        self.assertEqual(1.00002, position.average_open_price)
        self.assertEqual(2, position.event_count())
        self.assertEqual(ExecutionId("E2"), position.last_execution_id())
        self.assertEqual(PositionIdBroker("T123456"), position.id_broker)
        self.assertFalse(position.is_long())
        self.assertTrue(position.is_short())
        self.assertFalse(position.is_closed())
        self.assertEqual(0.0, position.realized_points)
        self.assertEqual(0.0, position.realized_return)
        self.assertEqual(Money(0, Currency.USD), position.realized_pnl)
        self.assertEqual(-0.000460000000000127, position.unrealized_points(last))
        self.assertEqual(-0.00045999080018412335, position.unrealized_return(last))
        self.assertEqual(Money(-46.00, Currency.USD), position.unrealized_pnl(last))
        self.assertEqual(-0.000460000000000127, position.total_points(last))
        self.assertEqual(-0.00045999080018412335, position.total_return(last))
        self.assertEqual(Money(-46.00, Currency.USD), position.total_pnl(last))

    def test_position_filled_with_buy_order_then_sell_order_returns_expected_attributes(self):
        # Arrange
        order = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.BUY,
            Quantity(100000))

        order_filled1 = OrderFilled(
            self.account_id,
            order.id,
            ExecutionId("E1"),
            PositionIdBroker("T123456"),
            order.symbol,
            OrderSide.BUY,
            order.quantity,
            Price(1.00001, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        position = Position(PositionId("P-123456"), order_filled1)

        order_filled2 = OrderFilled(
            self.account_id,
            order.id,
            ExecutionId("E2"),
            PositionIdBroker("T123456"),
            order.symbol,
            OrderSide.SELL,
            order.quantity,
            Price(1.00001, 5),
            Currency.USD,
            UNIX_EPOCH + timedelta(minutes=1),
            uuid4(),
            UNIX_EPOCH)

        last = QuoteTick(
            AUDUSD_FXCM,
            Price(1.00050, 5),
            Price(1.00048, 5),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

        # Act
        position.apply(order_filled2)

        # Assert
        self.assertEqual(Quantity(), position.quantity)
        self.assertEqual(MarketPosition.FLAT, position.market_position)
        self.assertEqual(UNIX_EPOCH, position.opened_time)
        self.assertEqual(timedelta(minutes=1), position.open_duration)
        self.assertEqual(1.00001, position.average_open_price)
        self.assertEqual(2, position.event_count())
        self.assertEqual(ExecutionId("E2"), position.last_execution_id())
        self.assertEqual(PositionIdBroker("T123456"), position.id_broker)
        self.assertEqual(datetime(1970, 1, 1, 0, 1, tzinfo=pytz.utc), position.closed_time)
        self.assertEqual(1.00001, position.average_close_price)
        self.assertFalse(position.is_long())
        self.assertFalse(position.is_short())
        self.assertTrue(position.is_closed())
        self.assertEqual(0.0, position.realized_points)
        self.assertEqual(0.0, position.realized_return)
        self.assertEqual(Money(0, Currency.USD), position.realized_pnl)
        self.assertEqual(0.0, position.unrealized_points(last))
        self.assertEqual(0.0, position.unrealized_return(last))
        self.assertEqual(Money(0, Currency.USD), position.unrealized_pnl(last))
        self.assertEqual(0.0, position.total_points(last))
        self.assertEqual(0.0, position.total_return(last))
        self.assertEqual(Money(0, Currency.USD), position.total_pnl(last))

    def test_position_filled_with_sell_order_then_buy_order_returns_expected_attributes(self):
        # Arrange
        order1 = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.SELL,
            Quantity(100000))

        order2 = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.BUY,
            Quantity(100000))

        order_filled1 = OrderFilled(
            self.account_id,
            order1.id,
            ExecutionId("E123456"),
            PositionIdBroker("T123456"),
            order1.symbol,
            order1.side,
            order1.quantity,
            Price(1.00000, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        position = Position(PositionId("P-123456"), order_filled1)

        order_filled2 = OrderPartiallyFilled(
            self.account_id,
            order2.id,
            ExecutionId("E1234561"),
            PositionIdBroker("T123456"),
            order2.symbol,
            order2.side,
            Quantity(50000),
            Quantity(50000),
            Price(1.00001, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        order_filled3 = OrderPartiallyFilled(
            self.account_id,
            order2.id,
            ExecutionId("E1234562"),
            PositionIdBroker("T123456"),
            order2.symbol,
            order2.side,
            Quantity(100000),
            Quantity(),
            Price(1.00003, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        last = QuoteTick(
            AUDUSD_FXCM,
            Price(1.00050, 5),
            Price(1.00048, 5),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

        # Act
        position.apply(order_filled2)
        position.apply(order_filled3)

        # Assert
        self.assertEqual(Quantity(), position.quantity)
        self.assertEqual(MarketPosition.FLAT, position.market_position)
        self.assertEqual(UNIX_EPOCH, position.opened_time)
        self.assertEqual(1.0, position.average_open_price)
        self.assertEqual(3, position.event_count())
        self.assertEqual([order1.id, order2.id], position.get_order_ids())
        self.assertEqual(ExecutionId("E1234562"), position.last_execution_id())
        self.assertEqual(PositionIdBroker("T123456"), position.id_broker)
        self.assertEqual(UNIX_EPOCH, position.closed_time)
        self.assertEqual(1.00003, position.average_close_price)
        self.assertFalse(position.is_long())
        self.assertFalse(position.is_short())
        self.assertTrue(position.is_closed())
        self.assertEqual(-2.999999999997449e-05, position.realized_points)
        self.assertEqual(-2.999999999997449e-05, position.realized_return)
        self.assertEqual(Money(-3.000, Currency.USD), position.realized_pnl)
        self.assertEqual(0.0, position.unrealized_points(last))
        self.assertEqual(0.0, position.unrealized_return(last))
        self.assertEqual(Money(00, Currency.USD), position.unrealized_pnl(last))
        self.assertEqual(-2.999999999997449e-05, position.total_points(last))
        self.assertEqual(-2.999999999997449e-05, position.total_return(last))
        self.assertEqual(Money(-3.000, Currency.USD), position.total_pnl(last))

    def test_position_filled_with_no_change_returns_expected_attributes(self):
        # Arrange
        order1 = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.BUY,
            Quantity(100000))

        order2 = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.SELL,
            Quantity(100000))

        order1_filled = OrderFilled(
            self.account_id,
            order1.id,
            ExecutionId("E1"),
            PositionIdBroker("T123456"),
            order1.symbol,
            order1.side,
            order1.quantity,
            Price(1.00000, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        position = Position(PositionId("P-123456"), order1_filled)

        order2_filled = OrderFilled(
            self.account_id,
            order2.id,
            ExecutionId("E2"),
            PositionIdBroker("T123456"),
            order2.symbol,
            order2.side,
            order2.quantity,
            Price(1.00000, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        last = QuoteTick(
            AUDUSD_FXCM,
            Price(1.00050, 5),
            Price(1.00048, 5),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

        # Act
        position.apply(order2_filled)

        # Assert
        self.assertEqual(Quantity(), position.quantity)
        self.assertEqual(MarketPosition.FLAT, position.market_position)
        self.assertEqual(UNIX_EPOCH, position.opened_time)
        self.assertEqual(1.0, position.average_open_price)
        self.assertEqual(2, position.event_count())
        self.assertEqual([order1.id, order2.id], position.get_order_ids())
        self.assertEqual([ExecutionId("E1"), ExecutionId("E2")], position.get_execution_ids()),
        self.assertEqual(ExecutionId("E2"), position.last_execution_id())
        self.assertEqual(PositionIdBroker("T123456"), position.id_broker)
        self.assertEqual(UNIX_EPOCH, position.closed_time)
        self.assertEqual(1.0, position.average_close_price)
        self.assertFalse(position.is_long())
        self.assertFalse(position.is_short())
        self.assertTrue(position.is_closed())
        self.assertEqual(0.0, position.realized_points)
        self.assertEqual(0.0, position.realized_return)
        self.assertEqual(Money(00, Currency.USD), position.realized_pnl)
        self.assertEqual(0.0, position.unrealized_points(last))
        self.assertEqual(0.0, position.unrealized_return(last))
        self.assertEqual(Money(00, Currency.USD), position.unrealized_pnl(last))
        self.assertEqual(0.0, position.total_points(last))
        self.assertEqual(0.0, position.total_return(last))
        self.assertEqual(Money(00, Currency.USD), position.total_pnl(last))

    def test_position_long_with_multiple_filled_orders_returns_expected_attributes(self):
        # Arrange
        order1 = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.BUY,
            Quantity(100000))

        order2 = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.BUY,
            Quantity(100000))

        order3 = self.order_factory.market(
            AUDUSD_FXCM,
            OrderSide.SELL,
            Quantity(200000))

        order1_filled = OrderFilled(
            self.account_id,
            order1.id,
            ExecutionId("E1"),
            PositionIdBroker("T123456"),
            order1.symbol,
            order1.side,
            order1.quantity,
            Price(1.00000, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        order2_filled = OrderFilled(
            self.account_id,
            order2.id,
            ExecutionId("E2"),
            PositionIdBroker("T123456"),
            order2.symbol,
            order2.side,
            order2.quantity,
            Price(1.00001, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        order3_filled = OrderFilled(
            self.account_id,
            order3.id,
            ExecutionId("E3"),
            PositionIdBroker("T123456"),
            order3.symbol,
            order3.side,
            order3.quantity,
            Price(1.00010, 5),
            Currency.USD,
            UNIX_EPOCH,
            uuid4(),
            UNIX_EPOCH)

        last = QuoteTick(
            AUDUSD_FXCM,
            Price(1.00050, 5),
            Price(1.00048, 5),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

        # Act
        position = Position(PositionId("P-123456"), order1_filled)
        position.apply(order2_filled)
        position.apply(order3_filled)

        # Assert
        self.assertEqual(Quantity(), position.quantity)
        self.assertEqual(MarketPosition.FLAT, position.market_position)
        self.assertEqual(UNIX_EPOCH, position.opened_time)
        self.assertEqual(1.000005, position.average_open_price)
        self.assertEqual(3, position.event_count())
        self.assertEqual([order1.id, order2.id, order3.id], position.get_order_ids())
        self.assertEqual(ExecutionId("E3"), position.last_execution_id())
        self.assertEqual(PositionIdBroker("T123456"), position.id_broker)
        self.assertEqual(UNIX_EPOCH, position.closed_time)
        self.assertEqual(1.0001, position.average_close_price)
        self.assertFalse(position.is_long())
        self.assertFalse(position.is_short())
        self.assertTrue(position.is_closed())
        self.assertEqual(9.499999999995623e-05, position.realized_points)
        self.assertEqual(9.499952500233122e-05, position.realized_return)
        self.assertEqual(Money(19.000, Currency.USD), position.realized_pnl)
        self.assertEqual(0.0, position.unrealized_points(last))
        self.assertEqual(0.0, position.unrealized_return(last))
        self.assertEqual(Money(00, Currency.USD), position.unrealized_pnl(last))
        self.assertEqual(9.499999999995623e-05, position.total_points(last))
        self.assertEqual(9.499952500233122e-05, position.total_return(last))
        self.assertEqual(Money(19.000, Currency.USD), position.total_pnl(last))
