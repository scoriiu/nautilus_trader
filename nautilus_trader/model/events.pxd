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

from nautilus_trader.core.message cimport Event
from nautilus_trader.model.c_enums.currency cimport Currency
from nautilus_trader.model.c_enums.order_side cimport OrderSide
from nautilus_trader.model.c_enums.order_type cimport OrderType
from nautilus_trader.model.c_enums.time_in_force cimport TimeInForce
from nautilus_trader.model.identifiers cimport AccountId
from nautilus_trader.model.identifiers cimport AccountNumber
from nautilus_trader.model.identifiers cimport Brokerage
from nautilus_trader.model.identifiers cimport ExecutionId
from nautilus_trader.model.identifiers cimport OrderId
from nautilus_trader.model.identifiers cimport OrderIdBroker
from nautilus_trader.model.identifiers cimport PositionIdBroker
from nautilus_trader.model.identifiers cimport StrategyId
from nautilus_trader.model.identifiers cimport Symbol
from nautilus_trader.model.objects cimport Decimal64
from nautilus_trader.model.objects cimport Money
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity
from nautilus_trader.model.position cimport Position


cdef class AccountStateEvent(Event):
    cdef readonly AccountId account_id
    cdef readonly Brokerage broker
    cdef readonly AccountNumber number
    cdef readonly Currency currency
    cdef readonly Money cash_balance
    cdef readonly Money cash_start_day
    cdef readonly Money cash_activity_day
    cdef readonly Money margin_used_liquidation
    cdef readonly Money margin_used_maintenance
    cdef readonly Decimal64 margin_ratio
    cdef readonly str margin_call_status


cdef class OrderEvent(Event):
    cdef readonly OrderId order_id


cdef class OrderFillEvent(OrderEvent):
    cdef readonly AccountId account_id
    cdef readonly ExecutionId execution_id
    cdef readonly PositionIdBroker position_id_broker
    cdef readonly Symbol symbol
    cdef readonly OrderSide order_side
    cdef readonly Quantity filled_quantity
    cdef readonly Price average_price
    cdef readonly Currency quote_currency
    cdef readonly datetime execution_time


cdef class OrderInitialized(OrderEvent):
    cdef readonly Symbol symbol
    cdef readonly OrderSide order_side
    cdef readonly OrderType order_type
    cdef readonly Quantity quantity
    cdef readonly Price price
    cdef readonly TimeInForce time_in_force
    cdef readonly datetime expire_time


cdef class OrderInvalid(OrderEvent):
    cdef readonly invalid_reason


cdef class OrderDenied(OrderEvent):
    cdef readonly denied_reason


cdef class OrderSubmitted(OrderEvent):
    cdef readonly AccountId account_id
    cdef readonly datetime submitted_time


cdef class OrderRejected(OrderEvent):
    cdef readonly AccountId account_id
    cdef readonly datetime rejected_time
    cdef readonly str rejected_reason


cdef class OrderAccepted(OrderEvent):
    cdef readonly AccountId account_id
    cdef readonly OrderIdBroker order_id_broker
    cdef readonly datetime accepted_time


cdef class OrderWorking(OrderEvent):
    cdef readonly AccountId account_id
    cdef readonly OrderIdBroker order_id_broker
    cdef readonly Symbol symbol
    cdef readonly OrderSide order_side
    cdef readonly OrderType order_type
    cdef readonly Quantity quantity
    cdef readonly Price price
    cdef readonly TimeInForce time_in_force
    cdef readonly datetime expire_time
    cdef readonly datetime working_time


cdef class OrderCancelReject(OrderEvent):
    cdef readonly AccountId account_id
    cdef readonly datetime rejected_time
    cdef readonly str rejected_response_to
    cdef readonly str rejected_reason


cdef class OrderCancelled(OrderEvent):
    cdef readonly AccountId account_id
    cdef readonly datetime cancelled_time


cdef class OrderExpired(OrderEvent):
    cdef readonly AccountId account_id
    cdef readonly datetime expired_time


cdef class OrderModified(OrderEvent):
    cdef readonly AccountId account_id
    cdef readonly OrderIdBroker order_id_broker
    cdef readonly Quantity modified_quantity
    cdef readonly Price modified_price
    cdef readonly datetime modified_time


cdef class OrderFilled(OrderFillEvent):
    pass


cdef class OrderPartiallyFilled(OrderFillEvent):
    cdef readonly Quantity leaves_quantity


cdef class PositionEvent(Event):
    cdef readonly Position position
    cdef readonly StrategyId strategy_id
    cdef readonly OrderEvent order_fill


cdef class PositionOpened(PositionEvent):
    pass


cdef class PositionModified(PositionEvent):
    pass


cdef class PositionClosed(PositionEvent):
    pass
