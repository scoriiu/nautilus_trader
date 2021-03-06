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

from nautilus_trader.core.types import Identifier
from nautilus_trader.model.enums import AccountType
from nautilus_trader.model.identifiers import AccountId
from nautilus_trader.model.identifiers import Brokerage
from nautilus_trader.model.identifiers import OrderId
from nautilus_trader.model.identifiers import PositionId
from nautilus_trader.model.identifiers import StrategyId
from nautilus_trader.model.identifiers import Symbol
from nautilus_trader.model.identifiers import TraderId
from nautilus_trader.model.identifiers import Venue


class IdentifierTests(unittest.TestCase):

    def test_identifier_equality(self):
        # Arrange
        id1 = Identifier("some-id-1")
        id2 = Identifier("some-id-2")

        # Act
        result1 = id1 == id1
        result2 = id1 != id1
        result3 = id1 == id2
        result4 = id1 != id2

        # Assert
        self.assertTrue(result1)
        self.assertFalse(result2)
        self.assertFalse(result3)
        self.assertTrue(result4)

    def test_identifier_to_string(self):
        # Arrange
        identifier = Identifier("some-id")

        # Act
        result = str(identifier)

        # Assert
        self.assertEqual("some-id", result)

    def test_identifier_repr(self):
        # Arrange
        identifier = Identifier("some-id")

        # Act
        result = repr(identifier)

        # Assert
        self.assertTrue(result.startswith("<Identifier(some-id) object at"))

    def test_mixed_identifier_equality(self):
        # Arrange
        id1 = OrderId("O-123456")
        id2 = PositionId("P-123456")

        # Act
        # Assert
        self.assertTrue(id1 == id1)
        self.assertFalse(id1 == id2)

    def test_symbol_equality(self):
        # Arrange
        symbol1 = Symbol("AUD/USD", Venue('FXCM'))
        symbol2 = Symbol("AUD/USD", Venue('IDEAL_PRO'))
        symbol3 = Symbol("GBP/USD", Venue('FXCM'))

        # Act
        # Assert
        self.assertTrue(symbol1 == symbol1)
        self.assertTrue(symbol1 != symbol2)
        self.assertTrue(symbol1 != symbol3)

    def test_symbol_str_and_repr(self):
        # Arrange
        symbol = Symbol("AUD/USD", Venue('FXCM'))

        # Act
        # Assert
        self.assertEqual("AUD/USD.FXCM", str(symbol))
        self.assertTrue(repr(symbol).startswith("<Symbol(AUD/USD.FXCM) object at"))

    def test_can_parse_symbol_from_string(self):
        # Arrange
        symbol = Symbol("AUD/USD", Venue('FXCM'))

        # Act
        result = Symbol.py_from_string(symbol.value)

        # Assert
        self.assertEqual(symbol, result)

    def test_trader_identifier(self):
        # Arrange
        # Act
        trader_id1 = TraderId("TESTER", "000")
        trader_id2 = TraderId("TESTER", "001")

        # Assert
        self.assertEqual(trader_id1, trader_id1)
        self.assertNotEqual(trader_id1, trader_id2)
        self.assertEqual("TESTER-000", trader_id1.value)
        self.assertEqual("TESTER", trader_id1.name)
        self.assertEqual(trader_id1, TraderId.py_from_string("TESTER-000"))

    def test_strategy_identifier(self):
        # Arrange
        # Act
        strategy_id1 = StrategyId("SCALPER", "00")
        strategy_id2 = StrategyId("SCALPER", "01")

        # Assert
        self.assertEqual(strategy_id1, strategy_id1)
        self.assertNotEqual(strategy_id1, strategy_id2)
        self.assertEqual("SCALPER-00", strategy_id1.value)
        self.assertEqual("SCALPER", strategy_id1.name)
        self.assertEqual(strategy_id1, StrategyId.py_from_string('SCALPER-00'))

    def test_account_identifier(self):
        # Arrange
        # Act
        account_id1 = AccountId('FXCM', "02851908", AccountType.DEMO)
        account_id2 = AccountId('FXCM', "09999999", AccountType.DEMO)

        # Assert
        self.assertEqual(account_id1, account_id1)
        self.assertNotEqual(account_id1, account_id2)
        self.assertEqual("FXCM-02851908-DEMO", account_id1.value)
        self.assertEqual(Brokerage('FXCM'), account_id1.broker)
        self.assertEqual(account_id1, AccountId.py_from_string("FXCM-02851908-DEMO"))
