#!/usr/bin/env python3
# -------------------------------------------------------------------------------------------------
# <copyright file="order.py" company="Invariance Pte">
#  Copyright (C) 2018 Invariance Pte. All rights reserved.
#  The use of this source code is governed by the license as found in the LICENSE.md file.
#  http://www.invariance.com
# </copyright>
# -------------------------------------------------------------------------------------------------

import datetime

from decimal import Decimal

from inv_trader.model.enums import OrderSide, OrderType, TimeInForce, OrderStatus
from inv_trader.model.objects import Symbol
from inv_trader.model.events import OrderEvent, OrderSubmitted
from inv_trader.model.events import OrderAccepted, OrderRejected, OrderWorking, OrderExpired
from inv_trader.model.events import OrderCancelled, OrderCancelReject, OrderPartiallyFilled, OrderFilled

orders_requiring_prices = [OrderType.LIMIT, OrderType.STOP_MARKET, OrderType.STOP_LIMIT, OrderType.MIT]


class Order:
    """
    Represents an order in a financial market.
    """

    def __init__(self,
                 symbol: Symbol,
                 identifier: str,
                 label: str,
                 order_side: OrderSide,
                 order_type: OrderType,
                 quantity: int,
                 timestamp: datetime.datetime,
                 price: Decimal = None,
                 time_in_force: TimeInForce=None,
                 expire_time: datetime.datetime=None):
        """
        Initializes a new instance of the Order class.

        :param: symbol: The orders symbol.
        :param: identifier: The orders identifier (id).
        :param: label: The orders label.
        :param: order_side: The orders side.
        :param: order_type: The orders type.
        :param: quantity: The orders quantity (> 0).
        :param: timestamp: The orders initialization timestamp.
        :param: price: The orders price (can be None for market orders > 0).
        :param: time_in_force: The orders time in force (optional can be None).
        :param: expire_time: The orders expire time (optional can be None).
        """
        # Preconditions
        if symbol is None:
            raise ValueError("The symbol cannot be None.")
        if not isinstance(symbol, Symbol):
            raise TypeError(f"The symbol must be of type Symbol (was {type(symbol)}).")
        if identifier is None:
            raise ValueError("The identifier cannot be None.")
        if not isinstance(identifier, str):
            raise TypeError(f"The identifier must be of type str (was {type(identifier)}).")
        if label is None:
            raise ValueError("The label cannot be None.")
        if not isinstance(label, str):
            raise TypeError(f"The label must be of type str (was {type(label)}).")
        if quantity <= 0:
            raise ValueError(f"The quantity must be positive (was {quantity}).")
        if not isinstance(quantity, int):
            raise TypeError(f"The quantity must be of type int (was {type(quantity)}).")
        if timestamp is None:
            raise ValueError("The timestamp cannot be None.")
        if not isinstance(timestamp, datetime.datetime):
            raise TypeError(f"The timestamp must be of type datetime (was {type(timestamp)}).")
        if time_in_force is not None and not isinstance(time_in_force, datetime.datetime):
            raise TypeError(
                f"The time_in_force must be of type datetime (was {type(time_in_force)}).")
        if time_in_force is TimeInForce.GTD and time_in_force is None:
            raise ValueError(f"The time_in_force cannot be None for GTD orders.")
        if time_in_force is TimeInForce.GTD and expire_time is None:
            raise ValueError(f"The expire_time cannot be None for GTD orders.")
        if order_type not in orders_requiring_prices and price is not None:
            raise ValueError(f"{order_type.name} orders cannot have a price.")
        if order_type in orders_requiring_prices and price is None:
            raise ValueError("The price cannot be None.")
        if order_type in orders_requiring_prices and not isinstance(price, Decimal):
            raise TypeError(f"The price must be of type decimal (was {type(price)}).")

        self._symbol = symbol
        self._id = identifier
        self._label = label
        self._order_side = order_side
        self._order_type = order_type
        self._quantity = quantity
        self._timestamp = timestamp
        self._time_in_force = time_in_force  # Can be None.
        self._expire_time = expire_time  # Can be None.
        self._price = price  # Can be None.
        self._filled_quantity = 0
        self._average_price = Decimal('0')
        self._order_status = OrderStatus.INITIALIZED

    @property
    def symbol(self) -> Symbol:
        """
        :return: The orders symbol.
        """
        return self._symbol

    @property
    def id(self) -> str:
        """
        :return: The orders id.
        """
        return self._id

    @property
    def label(self) -> str:
        """
        :return: The orders label.
        """
        return self._label

    @property
    def side(self) -> OrderSide:
        """
        :return: The orders side.
        """
        return self._order_side

    @property
    def type(self) -> OrderType:
        """
        :return: The orders type.
        """
        return self._order_type

    @property
    def quantity(self) -> int:
        """
        :return: The orders quantity.
        """
        return self._quantity

    @property
    def timestamp(self) -> datetime.datetime:
        """
        :return: The orders initialization timestamp.
        """
        return self._timestamp

    @property
    def time_in_force(self) -> TimeInForce:
        """
        :return: The orders time in force (optional could be None).
        """
        return self._time_in_force

    @property
    def expire_time(self) -> datetime.datetime:
        """
        :return: The orders expire time (optional could be None).
        """
        return self._expire_time

    @property
    def price(self) -> Decimal:
        """
        :return: The orders price (optional could be None).
        """
        return self._price

    @property
    def status(self) -> OrderStatus:
        """
        :return: The orders status.
        """
        return self._order_status

    @property
    def is_complete(self) -> bool:
        """
        :return: A value indicating whether the order is complete.
        """
        return (self._order_status is OrderStatus.CANCELLED
                or self._order_status is OrderStatus.EXPIRED
                or self._order_status is OrderStatus.FILLED
                or self._order_status is OrderStatus.REJECTED)

    def __eq__(self, other) -> bool:
        """
        Override the default equality comparison.
        """
        if isinstance(other, self.__class__):
            return self.__dict__ == other.__dict__
        else:
            return False

    def __ne__(self, other):
        """
        Override the default not-equals comparison.
        """
        return not self.__eq__(other)

    def __str__(self) -> str:
        """
        :return: The str() string representation of the order.
        """
        return f"Order: {self._id}"

    def __repr__(self) -> str:
        """
        :return: The repr() string representation of the order.
        """
        return f"<{str(self)} object at {id(self)}>"

    def apply(self, order_event: OrderEvent):
        """
        Applies the given order event to the order.

        :param order_event: The order event to apply.
        """
        if isinstance(order_event, OrderSubmitted):
            self._order_status = OrderStatus.SUBMITTED
        elif isinstance(order_event, OrderAccepted):
            self._order_status = OrderStatus.ACCEPTED
        elif isinstance(order_event, OrderRejected):
            self._order_status = OrderStatus.REJECTED
        elif isinstance(order_event, OrderWorking):
            self._order_status = OrderStatus.WORKING
        elif isinstance(order_event, OrderCancelled):
            self._order_status = OrderStatus.CANCELLED
        elif isinstance(order_event, OrderCancelReject):
            pass
        elif isinstance(order_event, OrderExpired):
            self._order_status = OrderStatus.EXPIRED
        elif isinstance(order_event, OrderFilled):
            self._order_status = OrderStatus.FILLED
        elif isinstance(order_event, OrderPartiallyFilled):
            self._order_status = OrderStatus.PARTIALLY_FILLED