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

import unittest

from nautilus_trader.model.bar import Bar
from nautilus_trader.model.objects import Price
from nautilus_trader.model.objects import Quantity
from nautilus_trader.model.tick import QuoteTick
from nautilus_trader.serialization.data import BsonDataSerializer
from nautilus_trader.serialization.data import DataMapper
from tests.test_kit.data import TestDataProvider
from tests.test_kit.stubs import TestStubs
from tests.test_kit.stubs import UNIX_EPOCH

AUDUSD_FXCM = TestStubs.symbol_audusd_fxcm()


class DataSerializerTests(unittest.TestCase):

    def setUp(self):
        # Fixture Setup
        self.mapper = DataMapper()
        self.serializer = BsonDataSerializer()
        self.test_ticks = TestDataProvider.usdjpy_test_ticks()

    def test_data_serializer_serialize_with_empty_dict_returns_empty_bson_doc(self):
        # Arrange
        serializer = BsonDataSerializer()

        # Act
        result = serializer.serialize({})

        # Assert
        self.assertEqual(b'\x05\x00\x00\x00\x00', result)

    def test_data_serializer_deserialize_with_empty_bson_doc_returns_empty_dict(self):
        # Arrange
        serializer = BsonDataSerializer()
        empty = serializer.serialize({})

        # Act
        result = serializer.deserialize(empty)

        # Assert
        self.assertEqual({}, result)

    def test_can_serialize_and_deserialize_quote_ticks(self):
        # Arrange
        tick = QuoteTick(
            AUDUSD_FXCM,
            Price(1.00000, 5),
            Price(1.00001, 5),
            Quantity(1),
            Quantity(1),
            UNIX_EPOCH)

        data = self.mapper.map_quote_ticks([tick])

        # Act
        serialized = self.serializer.serialize(data)

        print(type(data))
        print(data)
        print(type(serialized))
        deserialized = self.serializer.deserialize(serialized)

        print(deserialized)

        # Assert
        self.assertEqual(data, deserialized)

    def test_can_serialize_and_deserialize_bars(self):
        # Arrange
        bar_type = TestStubs.bartype_audusd_1min_bid()
        bar1 = Bar(Price(1.00001, 5),
                   Price(1.00004, 5),
                   Price(1.00002, 5),
                   Price(1.00003, 5),
                   Quantity(100000),
                   UNIX_EPOCH)

        data = self.mapper.map_bars([bar1, bar1], bar_type)

        # Act
        serialized = self.serializer.serialize(data)

        print(type(data))
        print(data)
        print(type(serialized))
        deserialized = self.serializer.deserialize(serialized)

        print(deserialized)

        # Assert
        self.assertEqual(data, deserialized)

    def test_can_deserialize_bar_data_response_from_csharp(self):
        # Arrange
        # Base64 bytes string from C# MsgPack.Cli
        bar_type = TestStubs.bartype_audusd_1min_bid()
        bar1 = Bar(Price(1.00001, 5),
                   Price(1.00004, 5),
                   Price(1.00002, 5),
                   Price(1.00003, 5),
                   Quantity(100000),
                   UNIX_EPOCH)

        data = self.mapper.map_bars([bar1, bar1], bar_type)

        # Act
        serialized = self.serializer.serialize(data)

        print(type(data))
        print(data)
        print(type(serialized))
        deserialized = self.serializer.deserialize(serialized)

        print(deserialized)

        # Assert
        self.assertEqual(data, deserialized)
