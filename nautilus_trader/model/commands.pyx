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

from nautilus_trader.core.uuid cimport UUID
from nautilus_trader.model.identifiers cimport AccountId
from nautilus_trader.model.identifiers cimport PositionId
from nautilus_trader.model.identifiers cimport StrategyId
from nautilus_trader.model.identifiers cimport TraderId
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.order cimport BracketOrder
from nautilus_trader.model.order cimport Order


cdef class AccountInquiry(Command):
    """
    Represents a request for account status.
    """

    def __init__(self,
                 TraderId trader_id not None,
                 AccountId account_id not None,
                 UUID command_id not None,
                 datetime command_timestamp not None):
        """
        Initialize a new instance of the AccountInquiry class.

        :param trader_id: The trader_id.
        :param account_id: The account_id for the inquiry.
        :param command_id: The command identifier.
        :param command_timestamp: The command timestamp.
        """
        super().__init__(command_id, command_timestamp)

        self.trader_id = trader_id
        self.account_id = account_id

    def __str__(self) -> str:
        """
        Return the string representation of this object.

        :return str.
        """
        return (f"{self.__class__.__name__}("
                f"trader_id={self.account_id.value}, "
                f"account_id={self.account_id.value})")


cdef class SubmitOrder(Command):
    """
    Represents a command to submit the given order.
    """

    def __init__(self,
                 TraderId trader_id not None,
                 AccountId account_id not None,
                 StrategyId strategy_id not None,
                 PositionId position_id not None,
                 Order order not None,
                 UUID command_id not None,
                 datetime command_timestamp not None):
        """
        Initialize a new instance of the SubmitOrder class.

        :param trader_id: The trader_id associated with the order.
        :param account_id: The account_id to submit the order to.
        :param strategy_id: The strategy_id associated with the order.
        :param position_id: The position_id associated with the order.
        :param order: The order to submit.
        :param command_id: The command identifier.
        :param command_timestamp: The command timestamp.
        """
        super().__init__(command_id, command_timestamp)

        self.trader_id = trader_id
        self.account_id = account_id
        self.strategy_id = strategy_id
        self.position_id = position_id
        self.order = order

    def __str__(self) -> str:
        """
        Return the string representation of this object.

        :return str.
        """
        return (f"{self.__class__.__name__}("
                f"trader_id={self.trader_id.value}, "
                f"account_id={self.account_id.value}, "
                f"strategy_id={self.strategy_id.value}, "
                f"position_id={self.position_id.value}, "
                f"order_id={self.order.id.value})")


cdef class SubmitBracketOrder(Command):
    """
    Represents a command to submit a bracket order consisting of parent and child orders.
    """

    def __init__(self,
                 TraderId trader_id not None,
                 AccountId account_id not None,
                 StrategyId strategy_id not None,
                 PositionId position_id not None,
                 BracketOrder bracket_order not None,
                 UUID command_id not None,
                 datetime command_timestamp not None):
        """
        Initialize a new instance of the SubmitBracketOrder class.

        :param trader_id: The trader_id associated with the order.
        :param account_id: The account_id to submit the order to.
        :param strategy_id: The strategy_id to associate with the order.
        :param position_id: The position_id to associate with the order.
        :param bracket_order: The bracket order to submit.
        :param command_id: The command identifier.
        :param command_timestamp: The command timestamp.
        """
        super().__init__(command_id, command_timestamp)

        self.trader_id = trader_id
        self.account_id = account_id
        self.strategy_id = strategy_id
        self.position_id = position_id
        self.bracket_order = bracket_order

    def __str__(self) -> str:
        """
        Return the string representation of this object.

        :return str.
        """
        return (f"{self.__class__.__name__}("
                f"trader_id={self.trader_id.value}, "
                f"account_id={self.account_id.value}, "
                f"strategy_id={self.strategy_id.value}, "
                f"position_id={self.position_id.value}, "
                f"order_id={self.bracket_order.id.value})")


cdef class ModifyOrder(Command):
    """
    Represents a command to modify an order with the given modified price.
    """

    def __init__(self,
                 TraderId trader_id not None,
                 AccountId account_id not None,
                 OrderId order_id not None,
                 Quantity modified_quantity not None,
                 Price modified_price not None,
                 UUID command_id not None,
                 datetime command_timestamp not None):
        """
        Initialize a new instance of the ModifyOrder class.

        :param trader_id: The trader_id for the command.
        :param account_id: The account_id for the command.
        :param order_id: The order_id.
        :param modified_price: The modified quantity for the order.
        :param modified_price: The modified price for the order.
        :param command_id: The command identifier.
        :param command_timestamp: The command timestamp.
        """
        super().__init__(command_id, command_timestamp)

        self.trader_id = trader_id
        self.account_id = account_id
        self.order_id = order_id
        self.modified_quantity = modified_quantity
        self.modified_price = modified_price

    def __str__(self) -> str:
        """
        Return the string representation of this object.

        :return str.
        """
        return (f"{self.__class__.__name__}("
                f"trader_id={self.trader_id.value}, "
                f"account_id={self.account_id.value}, "
                f"order_id={self.order_id.value}, "
                f"quantity={self.modified_quantity.to_string_formatted()}, "
                f"price={self.modified_price})")


cdef class CancelOrder(Command):
    """
    Represents a command to cancel an order.
    """

    def __init__(self,
                 TraderId trader_id not None,
                 AccountId account_id not None,
                 OrderId order_id not None,
                 UUID command_id not None,
                 datetime command_timestamp not None):
        """
        Initialize a new instance of the CancelOrder class.

        :param trader_id: The trader_id for the command.
        :param account_id: The account_id for the command.
        :param order_id: The order_id.
        :param command_id: The command identifier.
        :param command_timestamp: The command timestamp.
        """
        super().__init__(command_id, command_timestamp)

        self.trader_id = trader_id
        self.account_id = account_id
        self.order_id = order_id

    def __str__(self) -> str:
        """
        Return the string representation of this object.

        :return str.
        """
        return (f"{self.__class__.__name__}("
                f"trader_id={self.trader_id.value}, "
                f"account_id={self.account_id.value}, "
                f"order_id={self.order_id.value})")
