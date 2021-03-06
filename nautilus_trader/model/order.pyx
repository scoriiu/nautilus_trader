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

"""
Defines various Order types to be used for trading.
"""

from cpython.datetime cimport datetime

from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.core.datetime cimport format_iso8601
from nautilus_trader.core.decimal cimport Decimal64
from nautilus_trader.core.message cimport Event
from nautilus_trader.core.uuid cimport UUID
from nautilus_trader.model.c_enums.order_side cimport OrderSide
from nautilus_trader.model.c_enums.order_side cimport order_side_to_string
from nautilus_trader.model.c_enums.order_state cimport OrderState
from nautilus_trader.model.c_enums.order_state cimport order_state_to_string
from nautilus_trader.model.c_enums.order_type cimport OrderType
from nautilus_trader.model.c_enums.order_type cimport order_type_to_string
from nautilus_trader.model.c_enums.time_in_force cimport TimeInForce
from nautilus_trader.model.c_enums.time_in_force cimport time_in_force_to_string
from nautilus_trader.model.events cimport OrderAccepted
from nautilus_trader.model.events cimport OrderCancelled
from nautilus_trader.model.events cimport OrderDenied
from nautilus_trader.model.events cimport OrderEvent
from nautilus_trader.model.events cimport OrderExpired
from nautilus_trader.model.events cimport OrderFillEvent
from nautilus_trader.model.events cimport OrderFilled
from nautilus_trader.model.events cimport OrderInitialized
from nautilus_trader.model.events cimport OrderInvalid
from nautilus_trader.model.events cimport OrderModified
from nautilus_trader.model.events cimport OrderPartiallyFilled
from nautilus_trader.model.events cimport OrderRejected
from nautilus_trader.model.events cimport OrderSubmitted
from nautilus_trader.model.events cimport OrderWorking
from nautilus_trader.model.identifiers cimport ExecutionId
from nautilus_trader.model.identifiers cimport OrderId
from nautilus_trader.model.identifiers cimport Symbol
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity


# Order states which determine if the order is completed
cdef set _COMPLETED_STATES = {
    OrderState.INVALID,
    OrderState.DENIED,
    OrderState.REJECTED,
    OrderState.CANCELLED,
    OrderState.EXPIRED,
    OrderState.FILLED,
}


cdef dict _ORDER_STATE_TABLE = {
    (OrderState.INITIALIZED, OrderCancelled.__name__): OrderState.CANCELLED,
    (OrderState.INITIALIZED, OrderInvalid.__name__): OrderState.INVALID,
    (OrderState.INITIALIZED, OrderDenied.__name__): OrderState.DENIED,
    (OrderState.INITIALIZED, OrderSubmitted.__name__): OrderState.SUBMITTED,
    (OrderState.SUBMITTED, OrderCancelled.__name__): OrderState.CANCELLED,
    (OrderState.SUBMITTED, OrderRejected.__name__): OrderState.REJECTED,
    (OrderState.SUBMITTED, OrderAccepted.__name__): OrderState.ACCEPTED,
    (OrderState.SUBMITTED, OrderWorking.__name__): OrderState.WORKING,
    (OrderState.REJECTED, OrderRejected.__name__): OrderState.REJECTED,
    (OrderState.ACCEPTED, OrderCancelled.__name__): OrderState.CANCELLED,
    (OrderState.ACCEPTED, OrderWorking.__name__): OrderState.WORKING,
    (OrderState.ACCEPTED, OrderPartiallyFilled.__name__): OrderState.PARTIALLY_FILLED,
    (OrderState.ACCEPTED, OrderFilled.__name__): OrderState.FILLED,
    (OrderState.WORKING, OrderCancelled.__name__): OrderState.CANCELLED,
    (OrderState.WORKING, OrderModified.__name__): OrderState.WORKING,
    (OrderState.WORKING, OrderExpired.__name__): OrderState.EXPIRED,
    (OrderState.WORKING, OrderPartiallyFilled.__name__): OrderState.PARTIALLY_FILLED,
    (OrderState.WORKING, OrderFilled.__name__): OrderState.FILLED,
    (OrderState.PARTIALLY_FILLED, OrderCancelled.__name__): OrderState.PARTIALLY_FILLED,
    (OrderState.PARTIALLY_FILLED, OrderPartiallyFilled.__name__): OrderState.PARTIALLY_FILLED,
    (OrderState.PARTIALLY_FILLED, OrderFilled.__name__): OrderState.FILLED,
}


cdef class Order:
    """
    The base class for all orders.
    """

    def __init__(self, OrderInitialized event not None):
        """
        Initialize a new instance of the Order class.

        Parameters
        ----------
        event : OrderInitialized
            The order initialized event.

        """
        self._execution_ids = []  # type: [ExecutionId]
        self._events = []         # type: [OrderEvent]
        self._fsm = FiniteStateMachine(
            state_transition_table=_ORDER_STATE_TABLE,
            initial_state=OrderState.INITIALIZED,
            state_parser=order_state_to_string)

        self.id = event.order_id
        self.id_broker = None               # Can be None
        self.account_id = None              # Can be None
        self.position_id_broker = None      # Can be None
        self.execution_id = None            # Can be None
        self.symbol = event.symbol
        self.side = event.order_side
        self.type = event.order_type
        self.quantity = event.quantity
        self.timestamp = event.timestamp
        self.time_in_force = event.time_in_force
        self.filled_quantity = Quantity.zero()
        self.filled_timestamp = None        # Can be None
        self.average_price = None           # Can be None
        self.slippage = Decimal64()
        self.init_id = event.id

        self._events.append(event)

    cpdef bint equals(self, Order other):
        """
        Return a value indicating whether this object is equal to (==) the given object.

        :param other: The other object.
        :return bool.
        """
        return self.id.equals(other.id)

    cpdef OrderState state(self):
        """
        Return the orders current state.

        Returns
        -------
        OrderState

        """
        return self._fsm.state

    cpdef Event last_event(self):
        """
        Return the last event applied to the order.

        Returns
        -------
        OrderEvent

        """
        return self._events[-1]

    cpdef list get_execution_ids(self):
        """
        Return a sorted list of execution identifiers.

        :return List[ExecutionId].
        """
        return self._execution_ids.copy()

    cpdef list get_events(self):
        """
        Return a list or order events.

        :return List[OrderEvent].
        """
        return self._events.copy()

    cpdef int event_count(self):
        """
        Return the count of events received by the order.

        Returns
        -------
        int

        """
        return len(self._events)

    cpdef bint is_buy(self):
        """
        Return a value indicating whether the order side is buy.

        Returns
        -------
        bool

        """
        return self.side == OrderSide.BUY

    cpdef bint is_sell(self):
        """
        Return a value indicating whether the order side is sell.

        Returns
        -------
        bool

        """
        return self.side == OrderSide.SELL

    cpdef bint is_working(self):
        """
        Return a value indicating whether the order is working.

        Returns
        -------
        bool

        """
        return self._fsm.state == OrderState.WORKING

    cpdef bint is_completed(self):
        """
        Return a value indicating whether the order is completed.

        Returns
        -------
        bool

        """
        return self._fsm.state in _COMPLETED_STATES

    def __eq__(self, Order other) -> bool:
        """
        Return a value indicating whether this object is equal to (==) the given object.

        :param other: The other object.
        :return bool.
        """
        return self.equals(other)

    def __ne__(self, Order other) -> bool:
        """
        Return a value indicating whether this object is not equal to (!=) the given object.

        :param other: The other object.
        :return bool.
        """
        return not self.equals(other)

    def __hash__(self) -> int:
        """"
        Return the hash code of this object.

        :return int.
        """
        return hash(self.id)

    def __str__(self) -> str:
        """
        Return the string representation of this object.

        :return str.
        """
        return (f"{self.__class__.__name__}("
                f"id={self.id.value}, "
                f"state={self._fsm.state_as_string()}, "
                f"{self.status_string()})")

    def __repr__(self) -> str:
        """
        Return the string representation of this object which includes the objects
        location in memory.

        :return str.
        """
        return f"<{str(self)} object at {id(self)}>"

    cpdef str status_string(self):
        """
        Return the orders status as a string.

        :return str.
        """
        raise NotImplemented("method must be implemented in subclass")

    cpdef str state_as_string(self):
        """
        Return the order state as a string.

        :return str.
        """
        return self._fsm.state_as_string()

    cpdef void apply(self, OrderEvent event) except *:
        """
        Apply the given order event to the order.

        :param event: The order event to apply.
        :raises ValueError: If the order_events order_id is not equal to the event.order_id.
        :raises ValueError: If the order account_id is not None and is not equal to the event.account_id.
        """
        Condition.not_none(event, "event")
        Condition.equal(self.id, event.order_id, "id", "event.order_id")
        if self.account_id is not None:
            Condition.equal(self.account_id, event.account_id, "account_id", "event.account_id")

        # Update events
        self._events.append(event)

        # Update FSM (raises InvalidStateTrigger if trigger invalid)
        self._fsm.trigger(event.__class__.__name__)

        # Handle event
        if isinstance(event, OrderInvalid):
            self._invalid(event)
        elif isinstance(event, OrderDenied):
            self._denied(event)
        elif isinstance(event, OrderSubmitted):
            self._submitted(event)
        elif isinstance(event, OrderRejected):
            self._rejected(event)
        elif isinstance(event, OrderAccepted):
            self._accepted(event)
        elif isinstance(event, OrderWorking):
            self._working(event)
        elif isinstance(event, OrderCancelled):
            self._cancelled(event)
        elif isinstance(event, OrderExpired):
            self._expired(event)
        elif isinstance(event, OrderModified):
            self._modified(event)
        elif isinstance(event, OrderPartiallyFilled):
            self._filled(event)
        elif isinstance(event, OrderFilled):
            self._filled(event)

    cdef void _invalid(self, OrderInvalid event) except *:
        pass  # Do nothing else

    cdef void _denied(self, OrderDenied event) except *:
        pass  # Do nothing else

    cdef void _submitted(self, OrderSubmitted event) except *:
        self.account_id = event.account_id

    cdef void _rejected(self, OrderRejected event) except *:
        pass  # Do nothing else

    cdef void _accepted(self, OrderAccepted event) except *:
        pass  # Do nothing else

    cdef void _working(self, OrderWorking event) except *:
        self.id_broker = event.order_id_broker

    cdef void _cancelled(self, OrderCancelled event) except *:
        pass  # Do nothing else

    cdef void _expired(self, OrderExpired event) except *:
        pass  # Do nothing else

    cdef void _modified(self, OrderModified event) except *:
        raise NotImplemented("method must be implemented in subclass")

    cdef void _filled(self, OrderFillEvent event) except *:
        raise NotImplemented("method must be implemented in subclass")


cdef class PassiveOrder(Order):
    """
    The base class for all passive orders.
    """
    def __init__(self,
                 OrderId order_id not None,
                 Symbol symbol not None,
                 OrderSide order_side,
                 OrderType order_type,  # 'type' hides keyword
                 Quantity quantity not None,
                 Price price not None,
                 TimeInForce time_in_force,
                 datetime expire_time,  # Can be None
                 UUID init_id not None,
                 datetime timestamp not None):
        """
        Initialize a new instance of the PassiveOrder class.

        Parameters
        ----------
        order_id : OrderId
            The order unique identifier.
        symbol : Symbol
            The order symbol identifier.
        order_side : OrderSide (enum)
            The order side (BUY or SELL).
        order_type : OrderType (enum)
            The order type.
        quantity : Quantity
            The order quantity (> 0).
        price : Price
            The order price.
        time_in_force : TimeInForce
            The order time in force.
        expire_time : datetime, optional
            The order expiry time - for GTD orders only.
        init_id : UUID
            The order initialization event identifier.
        timestamp : datetime
            The order initialization timestamp.

        Raises
        ------
        ValueError
            If the quantities value is not positive (> 0).
            If the order_side is UNDEFINED.
            If the order_type is UNDEFINED.
            If the time_in_force is UNDEFINED.
            If the time_in_force is GTD and the expire_time is None.

        """
        Condition.positive(quantity.as_double(), "quantity")
        Condition.not_equal(time_in_force, TimeInForce.UNDEFINED, "time_in_force", "UNDEFINED")
        if time_in_force == TimeInForce.GTD:
            # Must have an expire time
            Condition.not_none(expire_time, "expire_time")
        else:
            # Should not have an expire time
            Condition.none(expire_time, "expire_time")

        cdef OrderInitialized init_event = OrderInitialized(
            order_id=order_id,
            symbol=symbol,
            order_side=order_side,
            order_type=order_type,
            quantity=quantity,
            price=price,
            time_in_force=time_in_force,
            expire_time=expire_time,
            event_id=init_id,
            event_timestamp=timestamp)
        super().__init__(init_event)

        self.price = price
        self.expire_time = expire_time
        self.slippage = Decimal64()

    cpdef str status_string(self):
        """
        Return the orders status as a string.

        :return str.
        """
        cdef str expire_time = "" if self.expire_time is None else f" {format_iso8601(self.expire_time)}"
        return (f"{order_side_to_string(self.side)} {self.quantity.to_string_formatted()} {self.symbol} "
                f"{order_type_to_string(self.type)} @ {self.price} "
                f"{time_in_force_to_string(self.time_in_force)}{expire_time}")

    cdef void _modified(self, OrderModified event) except *:
        self.id_broker = event.order_id_broker
        self.quantity = event.modified_quantity
        self.price = event.modified_price

    cdef void _filled(self, OrderFillEvent event) except *:
        self.position_id_broker = event.position_id_broker
        self._execution_ids.append(event.execution_id)
        self.execution_id = event.execution_id
        self.filled_quantity = event.filled_quantity
        self.filled_timestamp = event.timestamp
        self.average_price = event.average_price
        self._set_slippage()

    cdef void _set_slippage(self) except *:

        if self.side == OrderSide.BUY:
            self.slippage = Decimal64(self.average_price.as_double() - self.price.as_double(), self.average_price.precision)
        else:  # self.side == OrderSide.SELL:
            self.slippage = Decimal64(self.price.as_double() - self.average_price.as_double(), self.average_price.precision)


cdef set _MARKET_ORDER_VALID_TIF = {
    TimeInForce.DAY,
    TimeInForce.IOC,
    TimeInForce.FOC,
}

cdef class MarketOrder(Order):
    """
    The market order type. A market order is an order to buy or sell an instrument
    immediately. This type of order guarantees that the order will be executed, but does not
    guarantee the execution price. A market order generally will execute at or near the
    current bid (for a sell order) or ask (for a buy order) price. The last-traded price is
    not necessarily the price at which a market order will be executed.
    """
    def __init__(
            self,
            OrderId order_id not None,
            Symbol symbol not None,
            OrderSide order_side,
            Quantity quantity not None,
            TimeInForce time_in_force,
            UUID init_id not None,
            datetime timestamp not None):
        """
        Initialize a new instance of the MarketOrder class.

        Parameters
        ----------
        order_id : OrderId
            The order unique identifier.
        symbol : Symbol
            The order symbol identifier.
        order_side : OrderSide (enum)
            The order side (BUY or SELL).
        quantity : Quantity
            The order quantity (> 0).
        init_id : UUID
            The order initialization event identifier.
        timestamp : datetime
            The order initialization timestamp.

        Raises
        ------
        ValueError
            If the quantities value is not positive (> 0).
            If the order_side is UNDEFINED.

        """
        Condition.positive(quantity.as_double(), "quantity")
        Condition.true(time_in_force in _MARKET_ORDER_VALID_TIF, "time_in_force is DAY, IOC or FOC")

        cdef OrderInitialized init_event = OrderInitialized(
            order_id=order_id,
            symbol=symbol,
            order_side=order_side,
            order_type=OrderType.MARKET,
            quantity=quantity,
            price=None,
            time_in_force=time_in_force,
            expire_time=None,
            event_id=init_id,
            event_timestamp=timestamp)

        super().__init__(init_event)

    @staticmethod
    cdef MarketOrder create(OrderInitialized event):
        """
        Return an order from the given initialized event.

        :param event: The event to initialize with.
        :return Order.
        """
        Condition.not_none(event, "event")

        return MarketOrder(
            order_id=event.order_id,
            symbol=event.symbol,
            order_side=event.order_side,
            quantity=event.quantity,
            time_in_force=event.time_in_force,
            init_id=event.id,
            timestamp=event.timestamp)

    cpdef str status_string(self):
        """
        Return the orders status as a string.

        :return str.
        """
        return (f"{order_side_to_string(self.side)} {self.quantity.to_string_formatted()} {self.symbol} "
                f"{order_type_to_string(self.type)} "
                f"{time_in_force_to_string(self.time_in_force)}")

    cdef void _modified(self, OrderModified event) except *:
        raise NotImplemented("Cannot modify a market order")

    cdef void _filled(self, OrderFillEvent event) except *:
        self.position_id_broker = event.position_id_broker
        self._execution_ids.append(event.execution_id)
        self.execution_id = event.execution_id
        self.filled_quantity = event.filled_quantity
        self.filled_timestamp = event.timestamp
        self.average_price = event.average_price


cdef class LimitOrder(PassiveOrder):
    """
    Represents a limit order.
    """
    def __init__(self,
                 OrderId order_id not None,
                 Symbol symbol not None,
                 OrderSide order_side,
                 Quantity quantity not None,
                 Price price not None,
                 TimeInForce time_in_force,
                 datetime expire_time,  # Can be None
                 UUID init_id not None,
                 datetime timestamp not None):
        """
        Initialize a new instance of the LimitOrder class.

        Parameters
        ----------
        order_id : OrderId
            The order unique identifier.
        symbol : Symbol
            The order symbol identifier.
        order_side : OrderSide (enum)
            The order side (BUY or SELL).
        quantity : Quantity
            The order quantity (> 0).
        price : Price
            The order price.
        time_in_force : TimeInForce
            The order time in force.
        expire_time : datetime, optional
            The order expiry time.
        init_id : UUID
            The order initialization event identifier.
        timestamp : datetime
            The order initialization timestamp.

        Raises
        ------
        ValueError
            If the quantities value is not positive (> 0).
            If the order_side is UNDEFINED.
            If the time_in_force is UNDEFINED.
            If the time_in_force is GTD and the expire_time is None.

        """
        super().__init__(
            order_id,
            symbol,
            order_side,
            OrderType.LIMIT,
            quantity,
            price,
            time_in_force,
            expire_time,
            init_id,
            timestamp)

    @staticmethod
    cdef LimitOrder create(OrderInitialized event):
        """
        Return a limit order from the given initialized event.

        :param event: The event to initialize with.
        :return Order.
        """
        Condition.not_none(event, "event")

        return LimitOrder(
            order_id=event.order_id,
            symbol=event.symbol,
            order_side=event.order_side,
            quantity=event.quantity,
            price=event.price,
            time_in_force=event.time_in_force,
            expire_time=event.expire_time,
            init_id=event.id,
            timestamp=event.timestamp)


cdef class StopOrder(PassiveOrder):
    """
    Represents a stop order.
    """
    def __init__(self,
                 OrderId order_id not None,
                 Symbol symbol not None,
                 OrderSide order_side,
                 Quantity quantity not None,
                 Price price not None,
                 TimeInForce time_in_force,
                 datetime expire_time,  # Can be None
                 UUID init_id not None,
                 datetime timestamp not None):
        """
        Initialize a new instance of the StopOrder class.

        Parameters
        ----------
        order_id : OrderId
            The order unique identifier.
        symbol : Symbol
            The order symbol identifier.
        order_side : OrderSide (enum)
            The order side (BUY or SELL).
        quantity : Quantity
            The order quantity (> 0).
        price : Price
            The order price.
        time_in_force : TimeInForce
            The order time in force.
        expire_time : datetime, optional
            The order expiry time.
        init_id : UUID
            The order initialization event identifier.
        timestamp : datetime
            The order initialization timestamp.

        Raises
        ------
        ValueError
            If the quantities value is not positive (> 0).
            If the order_side is UNDEFINED.
            If the time_in_force is UNDEFINED.
            If the time_in_force is GTD and the expire_time is None.

        """
        super().__init__(
            order_id,
            symbol,
            order_side,
            OrderType.STOP,
            quantity,
            price,
            time_in_force,
            expire_time,
            init_id,
            timestamp)

    @staticmethod
    cdef StopOrder create(OrderInitialized event):
        """
        Return a stop order from the given initialized event.

        :param event: The event to initialize with.
        :return Order.
        """
        Condition.not_none(event, "event")

        return StopOrder(
            order_id=event.order_id,
            symbol=event.symbol,
            order_side=event.order_side,
            quantity=event.quantity,
            price=event.price,
            time_in_force=event.time_in_force,
            expire_time=event.expire_time,
            init_id=event.id,
            timestamp=event.timestamp)


cdef class BracketOrder:
    """
    Represents an order for a financial market instrument consisting of a 'parent'
    entry order and 'child' OCO orders representing a stop-loss and optional
    profit target.
    """
    def __init__(self,
                 Order entry not None,
                 StopOrder stop_loss not None,
                 LimitOrder take_profit=None):
        """
        Initialize a new instance of the BracketOrder class.

        Parameters
        ----------
        entry : Order
            The entry 'parent' order.
        stop_loss : StopOrder
            The stop-loss (SL) 'child' order.
        take_profit : LimitOrder, optional
            The take-profit (TP) 'child' order.

        """
        self.id = BracketOrderId(f"B{entry.id.value}")
        self.entry = entry
        self.stop_loss = stop_loss
        self.take_profit = take_profit
        self.has_take_profit = take_profit is not None
        self.timestamp = entry.timestamp

    cpdef bint equals(self, BracketOrder other):
        """
        Return a value indicating whether this object is equal to (==) the given object.

        :param other: The other object.
        :return bool.
        """
        return self.id.equals(other.id)

    def __eq__(self, BracketOrder other) -> bool:
        """
        Return a value indicating whether this object is equal to (==) the given object.

        :param other: The other object.
        :return bool.
        """
        return self.equals(other)

    def __ne__(self, BracketOrder other) -> bool:
        """
        Return a value indicating whether this object is not equal to (!=) the given object.

        :param other: The other object.
        :return bool.
        """
        return not self.equals(other)

    def __hash__(self) -> int:
        """"
        Return the hash code of this object.

        :return int.
        """
        return hash(self.id)

    def __str__(self) -> str:
        """
        Return the string representation of this object.

        :return str.
        """
        cdef str take_profit_price = "NONE" if self.take_profit is None or self.take_profit.price is None else self.take_profit.price.to_string()
        return f"BracketOrder(id={self.id.value}, Entry{self.entry}, SL={self.stop_loss.price}, TP={take_profit_price})"

    def __repr__(self) -> str:
        """
        Return the string representation of this object which includes the objects
        location in memory.

        :return str.
        """
        return f"<{str(self)} object at {id(self)}>"
