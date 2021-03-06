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

from pandas import Timestamp
import pytz

from nautilus_trader.backtest.clock import TestClock
from nautilus_trader.backtest.logging import TestLogger
from nautilus_trader.common.market import BarBuilder
from nautilus_trader.common.market import BarDataWrangler
from nautilus_trader.common.market import TickBarAggregator
from nautilus_trader.common.market import TickDataWrangler
from nautilus_trader.common.market import TimeBarAggregator
from nautilus_trader.model.bar import BarSpecification
from nautilus_trader.model.bar import BarType
from nautilus_trader.model.enums import BarAggregation
from nautilus_trader.model.enums import PriceType
from nautilus_trader.model.objects import Price
from nautilus_trader.model.objects import Quantity
from nautilus_trader.model.tick import QuoteTick
from tests.test_kit.data import TestDataProvider
from tests.test_kit.mocks import ObjectStorer
from tests.test_kit.stubs import TestStubs
from tests.test_kit.stubs import UNIX_EPOCH

AUDUSD_FXCM = TestStubs.symbol_audusd_fxcm()


class TickDataWranglerTests(unittest.TestCase):

    def setUp(self):
        self.clock = TestClock()

    def test_tick_data(self):
        # Arrange
        # Act
        ticks = TestDataProvider.usdjpy_test_ticks()

        # Assert
        self.assertEqual(1000, len(ticks))

    def test_build_with_tick_data(self):
        # Arrange
        tick_data = TestDataProvider.usdjpy_test_ticks()
        bid_data = TestDataProvider.usdjpy_1min_bid()
        ask_data = TestDataProvider.usdjpy_1min_ask()
        self.tick_builder = TickDataWrangler(
            instrument=TestStubs.instrument_usdjpy(),
            data_ticks=tick_data,
            data_bars_bid={BarAggregation.MINUTE: bid_data},
            data_bars_ask={BarAggregation.MINUTE: ask_data})

        # Act
        self.tick_builder.build(0)
        ticks = self.tick_builder.tick_data

        # Assert
        self.assertEqual(BarAggregation.TICK, self.tick_builder.resolution)
        self.assertEqual(1000, len(ticks))
        self.assertEqual(Timestamp("2013-01-01 22:02:35.907000", tz="UTC"), ticks.iloc[1].name)

    def test_build_ticks_with_bar_data(self):
        # Arrange
        bid_data = TestDataProvider.usdjpy_1min_bid()
        ask_data = TestDataProvider.usdjpy_1min_ask()
        self.tick_builder = TickDataWrangler(
            instrument=TestStubs.instrument_usdjpy(),
            data_ticks=None,
            data_bars_bid={BarAggregation.MINUTE: bid_data},
            data_bars_ask={BarAggregation.MINUTE: ask_data})

        # Act
        self.tick_builder.build(0)
        tick_data = self.tick_builder.tick_data

        # Assert
        self.assertEqual(BarAggregation.MINUTE, self.tick_builder.resolution)
        self.assertEqual(1491252, len(tick_data))
        self.assertEqual(Timestamp("2013-01-01T21:59:59.900000+00:00", tz="UTC"), tick_data.iloc[0].name)
        self.assertEqual(Timestamp("2013-01-01T21:59:59.900000+00:00", tz="UTC"), tick_data.iloc[1].name)
        self.assertEqual(Timestamp("2013-01-01T21:59:59.900000+00:00", tz="UTC"), tick_data.iloc[2].name)
        self.assertEqual(Timestamp("2013-01-01T22:00:00.000000+00:00", tz="UTC"), tick_data.iloc[3].name)
        self.assertEqual(0, tick_data.iloc[0]["symbol"])
        self.assertEqual(0, tick_data.iloc[0]["bid_size"])
        self.assertEqual(0, tick_data.iloc[0]["ask_size"])
        self.assertEqual(0, tick_data.iloc[1]["bid_size"])
        self.assertEqual(0, tick_data.iloc[1]["ask_size"])
        self.assertEqual(0, tick_data.iloc[2]["bid_size"])
        self.assertEqual(0, tick_data.iloc[2]["ask_size"])
        self.assertEqual(1.5, tick_data.iloc[3]["bid_size"])
        self.assertEqual(2.25, tick_data.iloc[3]["ask_size"])


class BarDataWranglerTests(unittest.TestCase):

    def setUp(self):
        data = TestDataProvider.gbpusd_1min_bid()[:1000]
        self.bar_builder = BarDataWrangler(5, 1, data)

    def test_can_build_bars_all(self):
        # Arrange
        # Act
        bars = self.bar_builder.build_bars_all()

        # Assert
        self.assertEqual(1000, len(bars))

    def test_can_build_bars_range_with_defaults(self):
        # Arrange
        # Act
        bars = self.bar_builder.build_bars_range()

        # Assert
        self.assertEqual(999, len(bars))

    def test_can_build_bars_range_with_param(self):
        # Arrange
        # Act
        bars = self.bar_builder.build_bars_range(start=500)

        # Assert
        self.assertEqual(499, len(bars))

    def test_can_build_bars_from_with_defaults(self):
        # Arrange
        # Act
        bars = self.bar_builder.build_bars_from()

        # Assert
        self.assertEqual(1000, len(bars))

    def test_can_build_bars_from_with_param(self):
        # Arrange
        # Act
        bars = self.bar_builder.build_bars_from(index=500)

        # Assert
        self.assertEqual(500, len(bars))


class BarBuilderTests(unittest.TestCase):

    def test_build_with_no_updates_raises_exception(self):
        # Arrange
        bar_spec = TestStubs.bar_spec_1min_mid()
        builder = BarBuilder(bar_spec, use_previous_close=False)

        # Act
        # Assert
        self.assertRaises(TypeError, builder.build)

    def test_update(self):
        # Arrange
        bar_spec = TestStubs.bar_spec_1min_mid()
        builder = BarBuilder(bar_spec, use_previous_close=True)

        tick1 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00001, 5),
            ask=Price(1.00004, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick2 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00002, 5),
            ask=Price(1.00005, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick3 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00000, 5),
            ask=Price(1.00003, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        # Act
        builder.update(tick1)
        builder.update(tick2)
        builder.update(tick3)

        # Assert
        self.assertEqual(bar_spec, builder.bar_spec)
        self.assertEqual(3, builder.count)
        self.assertEqual(UNIX_EPOCH, builder.last_update)

    def test_build_bid(self):
        # Arrange
        bar_spec = TestStubs.bar_spec_1min_bid()
        builder = BarBuilder(bar_spec, use_previous_close=True)

        tick1 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00001, 5),
            ask=Price(1.00004, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick2 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00002, 5),
            ask=Price(1.00005, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick3 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00000, 5),
            ask=Price(1.00003, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        builder.update(tick1)
        builder.update(tick2)
        builder.update(tick3)

        # Act
        bar = builder.build()  # Also resets builder

        # Assert
        self.assertEqual(Price(1.00001, 5), bar.open)
        self.assertEqual(Price(1.00002, 5), bar.high)
        self.assertEqual(Price(1.00000, 5), bar.low)
        self.assertEqual(Price(1.00000, 5), bar.close)
        self.assertEqual(Quantity(3, precision=0), bar.volume)
        self.assertEqual(UNIX_EPOCH, bar.timestamp)
        self.assertEqual(UNIX_EPOCH, builder.last_update)
        self.assertEqual(0, builder.count)

    def test_build_mid(self):
        # Arrange
        bar_spec = TestStubs.bar_spec_1min_mid()
        builder = BarBuilder(bar_spec, use_previous_close=True)

        tick1 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00001, 5),
            ask=Price(1.00004, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick2 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00002, 5),
            ask=Price(1.00005, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick3 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00000, 5),
            ask=Price(1.00003, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        builder.update(tick1)
        builder.update(tick2)
        builder.update(tick3)

        # Act
        bar = builder.build()  # Also resets builder

        # Assert
        self.assertEqual(Price(1.000025, 6), bar.open)
        self.assertEqual(Price(1.000035, 6), bar.high)
        self.assertEqual(Price(1.000015, 6), bar.low)
        self.assertEqual(Price(1.000015, 6), bar.close)
        self.assertEqual(Quantity(7), bar.volume)
        self.assertEqual(UNIX_EPOCH, bar.timestamp)
        self.assertEqual(UNIX_EPOCH, builder.last_update)
        self.assertEqual(0, builder.count)

    def test_build_with_previous_close(self):
        # Arrange
        bar_spec = TestStubs.bar_spec_1min_mid()
        builder = BarBuilder(bar_spec, use_previous_close=True)

        tick1 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00001, 5),
            ask=Price(1.00004, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick2 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00002, 5),
            ask=Price(1.00005, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick3 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00000, 5),
            ask=Price(1.00003, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        builder.update(tick1)
        builder.update(tick2)
        builder.update(tick3)
        builder.build()

        # Act
        bar = builder.build()  # Also resets builder

        # Assert
        self.assertEqual(Price(1.000015, 6), bar.open)
        self.assertEqual(Price(1.000015, 6), bar.high)
        self.assertEqual(Price(1.000015, 6), bar.low)
        self.assertEqual(Price(1.000015, 6), bar.close)
        self.assertEqual(Quantity(0), bar.volume)
        self.assertEqual(UNIX_EPOCH, bar.timestamp)
        self.assertEqual(UNIX_EPOCH, builder.last_update)
        self.assertEqual(0, builder.count)


class TickBarAggregatorTests(unittest.TestCase):

    def test_update_sends_bar_to_handler(self):
        # Arrange
        bar_store = ObjectStorer()
        handler = bar_store.store_2
        symbol = TestStubs.symbol_audusd_fxcm()
        bar_spec = BarSpecification(3, BarAggregation.TICK, PriceType.MID)
        bar_type = BarType(symbol, bar_spec)
        aggregator = TickBarAggregator(bar_type, handler, TestLogger(TestClock()))

        tick1 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00001, 5),
            ask=Price(1.00004, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick2 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00002, 5),
            ask=Price(1.00005, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick3 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00000, 5),
            ask=Price(1.00003, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        # Act
        aggregator.update(tick1)
        aggregator.update(tick2)
        aggregator.update(tick3)

        # Assert
        self.assertEqual(1, len(bar_store.get_store()))
        self.assertEqual(Price(1.000025, 6), bar_store.get_store()[0][1].open)
        self.assertEqual(Price(1.000035, 6), bar_store.get_store()[0][1].high)
        self.assertEqual(Price(1.000015, 6), bar_store.get_store()[0][1].low)
        self.assertEqual(Price(1.000015, 6), bar_store.get_store()[0][1].close)
        self.assertEqual(Quantity(7), bar_store.get_store()[0][1].volume)


class TimeBarAggregatorTests(unittest.TestCase):

    def test_update_timed_with_test_clock_sends_single_bar_to_handler(self):
        # Arrange
        clock = TestClock()
        bar_store = ObjectStorer()
        handler = bar_store.store_2
        symbol = TestStubs.symbol_audusd_fxcm()
        bar_spec = BarSpecification(1, BarAggregation.MINUTE, PriceType.MID)
        bar_type = BarType(symbol, bar_spec)
        aggregator = TimeBarAggregator(bar_type, handler, True, TestClock(), TestLogger(clock))

        stop_time = UNIX_EPOCH + timedelta(minutes=2)

        tick1 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00001, 5),
            ask=Price(1.00004, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick2 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00002, 5),
            ask=Price(1.00005, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=UNIX_EPOCH)

        tick3 = QuoteTick(
            symbol=AUDUSD_FXCM,
            bid=Price(1.00000, 5),
            ask=Price(1.00003, 5),
            bid_size=Quantity(1),
            ask_size=Quantity(1),
            timestamp=stop_time)

        # Act
        aggregator.update(tick1)
        aggregator.update(tick2)
        aggregator.update(tick3)

        # Assert
        self.assertEqual(1, len(bar_store.get_store()))
        self.assertEqual(Price(1.000025, 6), bar_store.get_store()[0][1].open)
        self.assertEqual(Price(1.000035, 6), bar_store.get_store()[0][1].high)
        self.assertEqual(Price(1.000025, 6), bar_store.get_store()[0][1].low)
        self.assertEqual(Price(1.000035, 6), bar_store.get_store()[0][1].close)
        self.assertEqual(Quantity(3), bar_store.get_store()[0][1].volume)
        self.assertEqual(datetime(1970, 1, 1, 0, 1, tzinfo=pytz.utc), bar_store.get_store()[0][1].timestamp)
