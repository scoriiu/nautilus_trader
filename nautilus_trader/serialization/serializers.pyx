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

import msgpack

from cpython.datetime cimport datetime

from nautilus_trader.common.cache cimport IdentifierCache
from nautilus_trader.common.logging cimport LogMessage
from nautilus_trader.common.logging cimport log_level_from_string
from nautilus_trader.core.cache cimport ObjectCache
from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.core.message cimport Command
from nautilus_trader.core.message cimport Event
from nautilus_trader.core.message cimport Request
from nautilus_trader.core.message cimport Response
from nautilus_trader.core.uuid cimport UUID
from nautilus_trader.model.c_enums.currency cimport Currency
from nautilus_trader.model.c_enums.currency cimport currency_from_string
from nautilus_trader.model.c_enums.currency cimport currency_to_string
from nautilus_trader.model.c_enums.order_side cimport OrderSide
from nautilus_trader.model.c_enums.order_side cimport order_side_from_string
from nautilus_trader.model.c_enums.order_side cimport order_side_to_string
from nautilus_trader.model.c_enums.order_type cimport OrderType
from nautilus_trader.model.c_enums.order_type cimport order_type_from_string
from nautilus_trader.model.c_enums.order_type cimport order_type_to_string
from nautilus_trader.model.c_enums.time_in_force cimport TimeInForce
from nautilus_trader.model.c_enums.time_in_force cimport time_in_force_from_string
from nautilus_trader.model.c_enums.time_in_force cimport time_in_force_to_string
from nautilus_trader.model.commands cimport AccountInquiry
from nautilus_trader.model.commands cimport CancelOrder
from nautilus_trader.model.commands cimport ModifyOrder
from nautilus_trader.model.commands cimport SubmitBracketOrder
from nautilus_trader.model.commands cimport SubmitOrder
from nautilus_trader.model.events cimport AccountStateEvent
from nautilus_trader.model.events cimport OrderAccepted
from nautilus_trader.model.events cimport OrderCancelReject
from nautilus_trader.model.events cimport OrderCancelled
from nautilus_trader.model.events cimport OrderDenied
from nautilus_trader.model.events cimport OrderExpired
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
from nautilus_trader.model.identifiers cimport OrderIdBroker
from nautilus_trader.model.identifiers cimport PositionId
from nautilus_trader.model.identifiers cimport PositionIdBroker
from nautilus_trader.model.identifiers cimport Symbol
from nautilus_trader.model.objects cimport Decimal64
from nautilus_trader.model.objects cimport Money
from nautilus_trader.model.objects cimport Quantity
from nautilus_trader.model.order cimport BracketOrder
from nautilus_trader.model.order cimport LimitOrder
from nautilus_trader.model.order cimport MarketOrder
from nautilus_trader.model.order cimport Order
from nautilus_trader.model.order cimport PassiveOrder
from nautilus_trader.model.order cimport StopOrder
from nautilus_trader.network.identifiers cimport ClientId
from nautilus_trader.network.identifiers cimport ServerId
from nautilus_trader.network.identifiers cimport SessionId
from nautilus_trader.network.messages cimport Connect
from nautilus_trader.network.messages cimport Connected
from nautilus_trader.network.messages cimport DataRequest
from nautilus_trader.network.messages cimport DataResponse
from nautilus_trader.network.messages cimport Disconnect
from nautilus_trader.network.messages cimport Disconnected
from nautilus_trader.network.messages cimport MessageReceived
from nautilus_trader.network.messages cimport MessageRejected
from nautilus_trader.network.messages cimport QueryFailure
from nautilus_trader.serialization.base cimport CommandSerializer
from nautilus_trader.serialization.base cimport EventSerializer
from nautilus_trader.serialization.base cimport LogSerializer
from nautilus_trader.serialization.base cimport OrderSerializer
from nautilus_trader.serialization.base cimport RequestSerializer
from nautilus_trader.serialization.base cimport ResponseSerializer
from nautilus_trader.serialization.common cimport convert_datetime_to_string
from nautilus_trader.serialization.common cimport convert_price_to_string
from nautilus_trader.serialization.common cimport convert_string_to_datetime
from nautilus_trader.serialization.common cimport convert_string_to_price
from nautilus_trader.serialization.constants cimport *


cdef class MsgPackSerializer:
    """
    Provides a serializer for the MessagePack specification.
    """
    @staticmethod
    cdef bytes serialize(dict message):
        """
        Serialize the given message to MessagePack specification bytes.

        :param message: The message to serialize.

        :return bytes.
        """
        Condition.not_none(message, "message")

        return msgpack.packb(message, use_bin_type=False)

    @staticmethod
    cdef dict deserialize(bytes message_bytes, bint raw_values=True):
        """
        Deserialize the given MessagePack specification bytes to a dictionary.

        :param message_bytes: The message bytes to deserialize.
        :param raw_values: If the values should be deserialized as raw bytes.
        :return Dict.
        """
        Condition.not_none(message_bytes, "message_bytes")

        cdef dict raw_unpacked = msgpack.unpackb(message_bytes, raw=True)

        cdef bytes k, v
        if raw_values:
            return {k.decode(UTF8): v for k, v in raw_unpacked.items()}
        return {k.decode(UTF8): v.decode(UTF8) for k, v in raw_unpacked.items()}


cdef class MsgPackDictionarySerializer(DictionarySerializer):
    """
    Provides a serializer for dictionaries for the MsgPack specification.
    """

    def __init__(self):
        """
        Initialize a new instance of the MsgPackDictionarySerializer class.
        """
        super().__init__()

    cpdef bytes serialize(self, dict dictionary):
        """
        Serialize the given dictionary with string keys and values to bytes.

        :param dictionary: The dictionary to serialize.
        :return bytes.
        """
        Condition.not_none(dictionary, "dictionary")

        return MsgPackSerializer.serialize(dictionary)

    cpdef dict deserialize(self, bytes dictionary_bytes):
        """
        Deserialize the given bytes to a dictionary with string keys and values.

        :param dictionary_bytes: The dictionary bytes to deserialize.
        :return Dict.
        """
        Condition.not_none(dictionary_bytes, "dictionary_bytes")

        return MsgPackSerializer.deserialize(dictionary_bytes, raw_values=False)


cdef class MsgPackOrderSerializer(OrderSerializer):
    """
    Provides a command serializer for the MessagePack specification.
    """

    def __init__(self):
        """
        Initialize a new instance of the MsgPackOrderSerializer class.
        """
        super().__init__()

        self.symbol_cache = ObjectCache(Symbol, Symbol.from_string)

    cpdef bytes serialize(self, Order order):  # Can be None
        """
        Return the serialized MessagePack specification bytes from the given order.

        :param order: The order to serialize.
        :return bytes.
        """
        if order is None:
            return MsgPackSerializer.serialize({})  # Null order

        cdef dict package = {
            ID: order.id.value,
            SYMBOL: order.symbol.value,
            ORDER_SIDE: self.convert_snake_to_camel(order_side_to_string(order.side)),
            ORDER_TYPE: self.convert_snake_to_camel(order_type_to_string(order.type)),
            QUANTITY: order.quantity.to_string(),
            TIME_IN_FORCE: time_in_force_to_string(order.time_in_force),
            INIT_ID: order.init_id.value,
            TIMESTAMP: convert_datetime_to_string(order.timestamp),
        }

        if isinstance(order, PassiveOrder):
            package[PRICE] = convert_price_to_string(order.price)
            package[EXPIRE_TIME] = convert_datetime_to_string(order.expire_time)

        return MsgPackSerializer.serialize(package)

    cpdef Order deserialize(self, bytes order_bytes):
        """
        Return the order deserialized from the given MessagePack specification bytes.

        :param order_bytes: The bytes to deserialize.
        :return Order.
        :raises ValueError: If the event_bytes is empty.
        """
        Condition.not_empty(order_bytes, "order_bytes")

        cdef dict unpacked = MsgPackSerializer.deserialize(order_bytes)

        if not unpacked:
            return None  # Null order

        cdef OrderId order_id = OrderId(unpacked[ID].decode(UTF8))
        cdef Symbol symbol = self.symbol_cache.get(unpacked[SYMBOL].decode(UTF8))
        cdef OrderSide order_side = order_side_from_string(self.convert_camel_to_snake(unpacked[ORDER_SIDE].decode(UTF8)))
        cdef OrderType order_type = order_type_from_string(self.convert_camel_to_snake(unpacked[ORDER_TYPE].decode(UTF8)))
        cdef Quantity quantity = Quantity.from_string(unpacked[QUANTITY].decode(UTF8))
        cdef TimeInForce time_in_force = time_in_force_from_string(unpacked[TIME_IN_FORCE].decode(UTF8))
        cdef UUID init_id = UUID(unpacked[INIT_ID].decode(UTF8))
        cdef datetime timestamp = convert_string_to_datetime(unpacked[TIMESTAMP].decode(UTF8))

        if order_type == OrderType.MARKET:
            return MarketOrder(
                order_id=order_id,
                symbol=symbol,
                order_side=order_side,
                quantity=quantity,
                time_in_force=time_in_force,
                init_id=init_id,
                timestamp=timestamp)

        if order_type == OrderType.LIMIT:
            return LimitOrder(
                order_id=order_id,
                symbol=symbol,
                order_side=order_side,
                quantity=quantity,
                price=convert_string_to_price(unpacked[PRICE].decode(UTF8)),
                time_in_force=time_in_force,
                expire_time=convert_string_to_datetime(unpacked[EXPIRE_TIME].decode(UTF8)),
                init_id=init_id,
                timestamp=timestamp)

        if order_type == OrderType.STOP:
            return StopOrder(
                order_id=order_id,
                symbol=symbol,
                order_side=order_side,
                quantity=quantity,
                price=convert_string_to_price(unpacked[PRICE].decode(UTF8)),
                time_in_force=time_in_force,
                expire_time=convert_string_to_datetime(unpacked[EXPIRE_TIME].decode(UTF8)),
                init_id=init_id,
                timestamp=timestamp)

        raise ValueError(f"Invalid order_type, was {order_type_to_string(order_type)}")


cdef class MsgPackCommandSerializer(CommandSerializer):
    """
    Provides a command serializer for the MessagePack specification.
    """

    def __init__(self):
        """
        Initialize a new instance of the MsgPackCommandSerializer class.
        """
        super().__init__()

        self.identifier_cache = IdentifierCache()
        self.order_serializer = MsgPackOrderSerializer()

    cpdef bytes serialize(self, Command command):
        """
        Return the serialized MessagePack specification bytes from the given command.

        :param command: The command to serialize.
        :return bytes.
        :raises: RuntimeError: If the command cannot be serialized.
        """
        Condition.not_none(command, "command")

        cdef dict package = {
            TYPE: command.__class__.__name__,
            ID: command.id.value,
            TIMESTAMP: convert_datetime_to_string(command.timestamp)
        }

        if isinstance(command, AccountInquiry):
            package[TRADER_ID] = command.trader_id.value
            package[ACCOUNT_ID] = command.account_id.value
        elif isinstance(command, SubmitOrder):
            package[TRADER_ID] = command.trader_id.value
            package[ACCOUNT_ID] = command.account_id.value
            package[STRATEGY_ID] = command.strategy_id.value
            package[POSITION_ID] = command.position_id.value
            package[ORDER] = self.order_serializer.serialize(command.order)
        elif isinstance(command, SubmitBracketOrder):
            package[TRADER_ID] = command.trader_id.value
            package[ACCOUNT_ID] = command.account_id.value
            package[STRATEGY_ID] = command.strategy_id.value
            package[POSITION_ID] = command.position_id.value
            package[ENTRY] = self.order_serializer.serialize(command.bracket_order.entry)
            package[STOP_LOSS] = self.order_serializer.serialize(command.bracket_order.stop_loss)
            package[TAKE_PROFIT] = self.order_serializer.serialize(command.bracket_order.take_profit)
        elif isinstance(command, ModifyOrder):
            package[TRADER_ID] = command.trader_id.value
            package[ACCOUNT_ID] = command.account_id.value
            package[ORDER_ID] = command.order_id.value
            package[MODIFIED_QUANTITY] = command.modified_quantity.to_string()
            package[MODIFIED_PRICE] = command.modified_price.to_string()
        elif isinstance(command, CancelOrder):
            package[TRADER_ID] = command.trader_id.value
            package[ACCOUNT_ID] = command.account_id.value
            package[ORDER_ID] = command.order_id.value
        else:
            raise RuntimeError("Cannot serialize command (unrecognized command).")

        return MsgPackSerializer.serialize(package)

    cpdef Command deserialize(self, bytes command_bytes):
        """
        Return the command deserialize from the given MessagePack specification command_bytes.

        :param command_bytes: The command to deserialize.
        :return Command.
        :raises ValueError: If the command_bytes is empty.
        :raises RuntimeError: If the command cannot be deserialized.
        """
        Condition.not_empty(command_bytes, "command_bytes")

        cdef dict unpacked = MsgPackSerializer.deserialize(command_bytes)  # type: {str, bytes}

        cdef str command_type = unpacked[TYPE].decode(UTF8)
        cdef UUID command_id = UUID(unpacked[ID].decode(UTF8))
        cdef datetime command_timestamp = convert_string_to_datetime(unpacked[TIMESTAMP].decode(UTF8))

        if command_type == AccountInquiry.__name__:
            return AccountInquiry(
                self.identifier_cache.get_trader_id(unpacked[TRADER_ID].decode(UTF8)),
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                command_id,
                command_timestamp)
        elif command_type == SubmitOrder.__name__:
            return SubmitOrder(
                self.identifier_cache.get_trader_id(unpacked[TRADER_ID].decode(UTF8)),
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                self.identifier_cache.get_strategy_id(unpacked[STRATEGY_ID].decode(UTF8)),
                PositionId(unpacked[POSITION_ID].decode(UTF8)),
                self.order_serializer.deserialize(unpacked[ORDER]),
                command_id,
                command_timestamp)
        elif command_type == SubmitBracketOrder.__name__:
            return SubmitBracketOrder(
                self.identifier_cache.get_trader_id(unpacked[TRADER_ID].decode(UTF8)),
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                self.identifier_cache.get_strategy_id(unpacked[STRATEGY_ID].decode(UTF8)),
                PositionId(unpacked[POSITION_ID].decode(UTF8)),
                BracketOrder(self.order_serializer.deserialize(unpacked[ENTRY]),
                             self.order_serializer.deserialize(unpacked[STOP_LOSS]),
                             self.order_serializer.deserialize(unpacked[TAKE_PROFIT])),
                command_id,
                command_timestamp)
        elif command_type == ModifyOrder.__name__:
            return ModifyOrder(
                self.identifier_cache.get_trader_id(unpacked[TRADER_ID].decode(UTF8)),
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                Quantity.from_string(unpacked[MODIFIED_QUANTITY].decode(UTF8)),
                convert_string_to_price(unpacked[MODIFIED_PRICE].decode(UTF8)),
                command_id,
                command_timestamp)
        elif command_type == CancelOrder.__name__:
            return CancelOrder(
                self.identifier_cache.get_trader_id(unpacked[TRADER_ID].decode(UTF8)),
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                command_id,
                command_timestamp)
        else:
            raise RuntimeError("Cannot deserialize command (unrecognized bytes pattern).")


cdef class MsgPackEventSerializer(EventSerializer):
    """
    Provides an event serializer for the MessagePack specification
    """

    def __init__(self):
        """
        Initialize a new instance of the MsgPackEventSerializer class.
        """
        super().__init__()

        self.identifier_cache = IdentifierCache()

    cpdef bytes serialize(self, Event event):
        """
        Return the MessagePack specification bytes serialized from the given event.

        :param event: The event to serialize.
        :return bytes.
        :raises: RuntimeError: If the event cannot be serialized.
        """
        Condition.not_none(event, "event")

        cdef dict package = {
            TYPE: event.__class__.__name__,
            ID: event.id.value,
            TIMESTAMP: convert_datetime_to_string(event.timestamp)
        }

        if isinstance(event, AccountStateEvent):
            package[ACCOUNT_ID] = event.account_id.value
            package[CURRENCY] = currency_to_string(event.currency)
            package[CASH_BALANCE] = event.cash_balance.to_string()
            package[CASH_START_DAY] = event.cash_start_day.to_string()
            package[CASH_ACTIVITY_DAY] = event.cash_activity_day.to_string()
            package[MARGIN_USED_LIQUIDATION] = event.margin_used_liquidation.to_string()
            package[MARGIN_USED_MAINTENANCE] = event.margin_used_maintenance.to_string()
            package[MARGIN_RATIO] = event.margin_ratio.to_string()
            package[MARGIN_CALL_STATUS] = event.margin_call_status
        elif isinstance(event, OrderInitialized):
            package[ORDER_ID] = event.order_id.value
            package[SYMBOL] = event.symbol.value
            package[ORDER_SIDE] = self.convert_snake_to_camel(order_side_to_string(event.order_side))
            package[ORDER_TYPE] = self.convert_snake_to_camel(order_type_to_string(event.order_type))
            package[QUANTITY] = event.quantity.to_string()
            package[PRICE] = convert_price_to_string(event.price)
            package[TIME_IN_FORCE] = time_in_force_to_string(event.time_in_force)
            package[EXPIRE_TIME] = convert_datetime_to_string(event.expire_time)
        elif isinstance(event, OrderSubmitted):
            package[ORDER_ID] = event.order_id.value
            package[ACCOUNT_ID] = event.account_id.value
            package[SUBMITTED_TIME] = convert_datetime_to_string(event.submitted_time)
        elif isinstance(event, OrderInvalid):
            package[ORDER_ID] = event.order_id.value
            package[INVALID_REASON] = event.invalid_reason
        elif isinstance(event, OrderDenied):
            package[ORDER_ID] = event.order_id.value
            package[DENIED_REASON] = event.denied_reason
        elif isinstance(event, OrderAccepted):
            package[ACCOUNT_ID] = event.account_id.value
            package[ORDER_ID] = event.order_id.value
            package[ORDER_ID_BROKER] = event.order_id_broker.value
            package[ACCEPTED_TIME] = convert_datetime_to_string(event.accepted_time)
        elif isinstance(event, OrderRejected):
            package[ORDER_ID] = event.order_id.value
            package[ACCOUNT_ID] = event.account_id.value
            package[REJECTED_TIME] = convert_datetime_to_string(event.rejected_time)
            package[REJECTED_REASON] = event.rejected_reason
        elif isinstance(event, OrderWorking):
            package[ORDER_ID] = event.order_id.value
            package[ACCOUNT_ID] = event.account_id.value
            package[ORDER_ID_BROKER] = event.order_id_broker.value
            package[SYMBOL] = event.symbol.value
            package[ORDER_SIDE] = self.convert_snake_to_camel(order_side_to_string(event.order_side))
            package[ORDER_TYPE] = self.convert_snake_to_camel(order_type_to_string(event.order_type))
            package[QUANTITY] = event.quantity.to_string()
            package[PRICE] = event.price.to_string()
            package[TIME_IN_FORCE] = time_in_force_to_string(event.time_in_force)
            package[EXPIRE_TIME] = convert_datetime_to_string(event.expire_time)
            package[WORKING_TIME] = convert_datetime_to_string(event.working_time)
        elif isinstance(event, OrderCancelReject):
            package[ORDER_ID] = event.order_id.value
            package[ACCOUNT_ID] = event.account_id.value
            package[REJECTED_TIME] = convert_datetime_to_string(event.rejected_time)
            package[REJECTED_RESPONSE_TO] = event.rejected_response_to
            package[REJECTED_REASON] = event.rejected_reason
        elif isinstance(event, OrderCancelled):
            package[ORDER_ID] = event.order_id.value
            package[ACCOUNT_ID] = event.account_id.value
            package[CANCELLED_TIME] = convert_datetime_to_string(event.cancelled_time)
        elif isinstance(event, OrderModified):
            package[ORDER_ID] = event.order_id.value
            package[ACCOUNT_ID] = event.account_id.value
            package[ORDER_ID_BROKER] = event.order_id_broker.value
            package[MODIFIED_TIME] = convert_datetime_to_string(event.modified_time)
            package[MODIFIED_QUANTITY] = event.modified_quantity.to_string()
            package[MODIFIED_PRICE] = event.modified_price.to_string()
        elif isinstance(event, OrderExpired):
            package[ORDER_ID] = event.order_id.value
            package[ACCOUNT_ID] = event.account_id.value
            package[EXPIRED_TIME] = convert_datetime_to_string(event.expired_time)
        elif isinstance(event, OrderPartiallyFilled):
            package[ORDER_ID] = event.order_id.value
            package[ACCOUNT_ID] = event.account_id.value
            package[EXECUTION_ID] = event.execution_id.value
            package[POSITION_ID_BROKER] = event.position_id_broker.value
            package[SYMBOL] = event.symbol.value
            package[ORDER_SIDE] = self.convert_snake_to_camel(order_side_to_string(event.order_side))
            package[FILLED_QUANTITY] = event.filled_quantity.to_string()
            package[LEAVES_QUANTITY] = event.leaves_quantity.to_string()
            package[AVERAGE_PRICE] = event.average_price.to_string()
            package[CURRENCY] = currency_to_string(event.quote_currency)
            package[EXECUTION_TIME] = convert_datetime_to_string(event.execution_time)
        elif isinstance(event, OrderFilled):
            package[ORDER_ID] = event.order_id.value
            package[ACCOUNT_ID] = event.account_id.value
            package[EXECUTION_ID] = event.execution_id.value
            package[POSITION_ID_BROKER] = event.position_id_broker.value
            package[SYMBOL] = event.symbol.value
            package[ORDER_SIDE] = self.convert_snake_to_camel(order_side_to_string(event.order_side))
            package[FILLED_QUANTITY] = event.filled_quantity.to_string()
            package[AVERAGE_PRICE] = event.average_price.to_string()
            package[CURRENCY] = currency_to_string(event.quote_currency)
            package[EXECUTION_TIME] = convert_datetime_to_string(event.execution_time)
        else:
            raise RuntimeError("Cannot serialize event (unrecognized event.")

        return MsgPackSerializer.serialize(package)

    cpdef Event deserialize(self, bytes event_bytes):
        """
        Return the event deserialized from the given MessagePack specification event_bytes.

        :param event_bytes: The bytes to deserialize.
        :return Event.
        :raises ValueError: If the event_bytes is empty.
        :raises RuntimeError: If the event cannot be deserialized.
        """
        Condition.not_empty(event_bytes, "event_bytes")

        cdef dict unpacked = MsgPackSerializer.deserialize(event_bytes)  # type: {str, bytes}

        cdef str event_type = unpacked[TYPE].decode(UTF8)
        cdef UUID event_id = UUID(unpacked[ID].decode(UTF8))
        cdef datetime event_timestamp = convert_string_to_datetime(unpacked[TIMESTAMP].decode(UTF8))

        cdef Currency currency
        if event_type == AccountStateEvent.__name__:
            currency = currency_from_string(unpacked[CURRENCY].decode(UTF8))
            return AccountStateEvent(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                currency,
                Money.from_string(unpacked[CASH_BALANCE].decode(UTF8), currency),
                Money.from_string(unpacked[CASH_START_DAY].decode(UTF8), currency),
                Money.from_string(unpacked[CASH_ACTIVITY_DAY].decode(UTF8), currency),
                Money.from_string(unpacked[MARGIN_USED_LIQUIDATION].decode(UTF8), currency),
                Money.from_string(unpacked[MARGIN_USED_MAINTENANCE].decode(UTF8), currency),
                Decimal64.from_string_to_decimal(unpacked[MARGIN_RATIO].decode(UTF8)),
                unpacked[MARGIN_CALL_STATUS].decode(UTF8),
                event_id,
                event_timestamp)
        elif event_type == OrderInitialized.__name__:
            return OrderInitialized(
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                self.identifier_cache.get_symbol(unpacked[SYMBOL].decode(UTF8)),
                order_side_from_string(self.convert_camel_to_snake(unpacked[ORDER_SIDE].decode(UTF8))),
                order_type_from_string(self.convert_camel_to_snake(unpacked[ORDER_TYPE].decode(UTF8))),
                Quantity.from_string(unpacked[QUANTITY].decode(UTF8)),
                convert_string_to_price(unpacked[PRICE].decode(UTF8)),
                time_in_force_from_string(unpacked[TIME_IN_FORCE].decode(UTF8)),
                convert_string_to_datetime(unpacked[EXPIRE_TIME].decode(UTF8)),
                event_id,
                event_timestamp)
        elif event_type == OrderSubmitted.__name__:
            return OrderSubmitted(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                convert_string_to_datetime(unpacked[SUBMITTED_TIME].decode(UTF8)),
                event_id,
                event_timestamp)
        elif event_type == OrderInvalid.__name__:
            return OrderInvalid(
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                unpacked[INVALID_REASON].decode(UTF8),
                event_id,
                event_timestamp)
        elif event_type == OrderDenied.__name__:
            return OrderDenied(
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                unpacked[DENIED_REASON].decode(UTF8),
                event_id,
                event_timestamp)
        elif event_type == OrderAccepted.__name__:
            return OrderAccepted(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                OrderIdBroker(unpacked[ORDER_ID_BROKER].decode(UTF8)),
                convert_string_to_datetime(unpacked[ACCEPTED_TIME].decode(UTF8)),
                event_id,
                event_timestamp)
        elif event_type == OrderRejected.__name__:
            return OrderRejected(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                convert_string_to_datetime(unpacked[REJECTED_TIME].decode(UTF8)),
                unpacked[REJECTED_REASON].decode(UTF8),
                event_id,
                event_timestamp)
        elif event_type == OrderWorking.__name__:
            return OrderWorking(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                OrderIdBroker(unpacked[ORDER_ID_BROKER].decode(UTF8)),
                Symbol.from_string(unpacked[SYMBOL].decode(UTF8)),
                order_side_from_string(self.convert_camel_to_snake(unpacked[ORDER_SIDE].decode(UTF8))),
                order_type_from_string(self.convert_camel_to_snake(unpacked[ORDER_TYPE].decode(UTF8))),
                Quantity.from_string(unpacked[QUANTITY].decode(UTF8)),
                convert_string_to_price(unpacked[PRICE].decode(UTF8)),
                time_in_force_from_string(unpacked[TIME_IN_FORCE].decode(UTF8)),
                convert_string_to_datetime(unpacked[EXPIRE_TIME].decode(UTF8)),
                convert_string_to_datetime(unpacked[WORKING_TIME].decode(UTF8)),
                event_id,
                event_timestamp)
        elif event_type == OrderCancelled.__name__:
            return OrderCancelled(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                convert_string_to_datetime(unpacked[CANCELLED_TIME].decode(UTF8)),
                event_id,
                event_timestamp)
        elif event_type == OrderCancelReject.__name__:
            return OrderCancelReject(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                convert_string_to_datetime(unpacked[REJECTED_TIME].decode(UTF8)),
                unpacked[REJECTED_RESPONSE_TO].decode(UTF8),
                unpacked[REJECTED_REASON].decode(UTF8),
                event_id,
                event_timestamp)
        elif event_type == OrderModified.__name__:
            return OrderModified(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                OrderIdBroker(unpacked[ORDER_ID_BROKER].decode(UTF8)),
                Quantity.from_string(unpacked[MODIFIED_QUANTITY].decode(UTF8)),
                convert_string_to_price(unpacked[MODIFIED_PRICE].decode(UTF8)),
                convert_string_to_datetime(unpacked[MODIFIED_TIME].decode(UTF8)),
                event_id,
                event_timestamp)
        elif event_type == OrderExpired.__name__:
            return OrderExpired(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                convert_string_to_datetime(unpacked[EXPIRED_TIME].decode(UTF8)),
                event_id,
                event_timestamp)
        elif event_type == OrderPartiallyFilled.__name__:
            return OrderPartiallyFilled(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                ExecutionId(unpacked[EXECUTION_ID].decode(UTF8)),
                PositionIdBroker(unpacked[POSITION_ID_BROKER].decode(UTF8)),
                self.identifier_cache.get_symbol(unpacked[SYMBOL].decode(UTF8)),
                order_side_from_string(self.convert_camel_to_snake(unpacked[ORDER_SIDE].decode(UTF8))),
                Quantity.from_string(unpacked[FILLED_QUANTITY].decode(UTF8)),
                Quantity.from_string(unpacked[LEAVES_QUANTITY].decode(UTF8)),
                convert_string_to_price(unpacked[AVERAGE_PRICE].decode(UTF8)),
                currency_from_string(unpacked[CURRENCY].decode(UTF8)),
                convert_string_to_datetime(unpacked[EXECUTION_TIME].decode(UTF8)),
                event_id,
                event_timestamp)
        elif event_type == OrderFilled.__name__:
            return OrderFilled(
                self.identifier_cache.get_account_id(unpacked[ACCOUNT_ID].decode(UTF8)),
                OrderId(unpacked[ORDER_ID].decode(UTF8)),
                ExecutionId(unpacked[EXECUTION_ID].decode(UTF8)),
                PositionIdBroker(unpacked[POSITION_ID_BROKER].decode(UTF8)),
                self.identifier_cache.get_symbol(unpacked[SYMBOL].decode(UTF8)),
                order_side_from_string(self.convert_camel_to_snake(unpacked[ORDER_SIDE].decode(UTF8))),
                Quantity.from_string(unpacked[FILLED_QUANTITY].decode(UTF8)),
                convert_string_to_price(unpacked[AVERAGE_PRICE].decode(UTF8)),
                currency_from_string(unpacked[CURRENCY].decode(UTF8)),
                convert_string_to_datetime(unpacked[EXECUTION_TIME].decode(UTF8)),
                event_id,
                event_timestamp)
        else:
            raise RuntimeError("Cannot deserialize event (unrecognized event).")


cdef class MsgPackRequestSerializer(RequestSerializer):
    """
    Provides a request serializer for the MessagePack specification.
    """

    def __init__(self):
        """
        Initialize a new instance of the MsgPackRequestSerializer class.
        """
        super().__init__()

        self.dict_serializer = MsgPackDictionarySerializer()

    cpdef bytes serialize(self, Request request):
        """
        Serialize the given request to bytes.

        :param request: The request to serialize.
        :return bytes.
        :raises RuntimeError: If the request cannot be serialized.
        """
        Condition.not_none(request, "request")

        cdef dict package = {
            TYPE: request.__class__.__name__,
            ID: request.id.value,
            TIMESTAMP: convert_datetime_to_string(request.timestamp)
        }

        if isinstance(request, Connect):
            package[CLIENT_ID] = request.client_id.value
            package[AUTHENTICATION] = request.authentication
        elif isinstance(request, Disconnect):
            package[CLIENT_ID] = request.client_id.value
            package[SESSION_ID] = request.session_id.value
        elif isinstance(request, DataRequest):
            package[QUERY] = self.dict_serializer.serialize(request.query)
        else:
            raise RuntimeError("Cannot serialize request (unrecognized request.")

        return MsgPackSerializer.serialize(package)

    cpdef Request deserialize(self, bytes request_bytes):
        """
        Deserialize the given bytes to a request.

        :param request_bytes: The bytes to deserialize.
        :return Request.
        :raises RuntimeError: If the request cannot be deserialized.
        """
        Condition.not_empty(request_bytes, "request_bytes")

        cdef dict unpacked = MsgPackSerializer.deserialize(request_bytes)  # type: {str, bytes}

        cdef str request_type = unpacked[TYPE].decode(UTF8)
        cdef UUID request_id = UUID(unpacked[ID].decode(UTF8))
        cdef datetime request_timestamp = convert_string_to_datetime(unpacked[TIMESTAMP].decode(UTF8))

        if request_type == Connect.__name__:
            return Connect(
                ClientId(unpacked[CLIENT_ID].decode(UTF8)),
                unpacked[AUTHENTICATION].decode(UTF8),
                request_id,
                request_timestamp)
        elif request_type == Disconnect.__name__:
            return Disconnect(
                ClientId(unpacked[CLIENT_ID].decode(UTF8)),
                SessionId(unpacked[SESSION_ID].decode(UTF8)),
                request_id,
                request_timestamp)
        elif request_type == DataRequest.__name__:
            return DataRequest(
                self.dict_serializer.deserialize(unpacked[QUERY]),
                request_id,
                request_timestamp)
        else:
            raise RuntimeError("Cannot deserialize request (unrecognized request).")


cdef class MsgPackResponseSerializer(ResponseSerializer):
    """
    Provides a response serializer for the MessagePack specification.
    """

    def __init__(self):
        """
        Initialize a new instance of the MsgPackResponseSerializer class.
        """
        super().__init__()

    cpdef bytes serialize(self, Response response):
        """
        Serialize the given response to bytes.

        :param response: The response to serialize.
        :return bytes.
        :raises RuntimeError: If the response cannot be serialized.
        """
        Condition.not_none(response, "response")

        cdef dict package = {
            TYPE: response.__class__.__name__,
            ID: response.id.value,
            CORRELATION_ID: response.correlation_id.value,
            TIMESTAMP: convert_datetime_to_string(response.timestamp)
        }

        if isinstance(response, Connected):
            package[MESSAGE] = response.message
            package[SERVER_ID] = response.server_id.value
            package[SESSION_ID] = response.session_id.value
        elif isinstance(response, Disconnected):
            package[MESSAGE] = response.message
            package[SERVER_ID] = response.server_id.value
            package[SESSION_ID] = response.session_id.value
        elif isinstance(response, MessageReceived):
            package[RECEIVED_TYPE] = response.received_type
        elif isinstance(response, MessageRejected):
            package[MESSAGE] = response.message
        elif isinstance(response, DataResponse):
            package[DATA] = response.data
            package[DATA_TYPE] = response.data_type
            package[DATA_ENCODING] = response.data_encoding
        else:
            raise RuntimeError("Cannot serialize response (unrecognized response.")

        return MsgPackSerializer.serialize(package)

    cpdef Response deserialize(self, bytes response_bytes):
        """
        Deserialize the given bytes to a response.

        :param response_bytes: The bytes to deserialize.
        :return Response.
        :raises RuntimeError: If the response cannot be deserialized.
        """
        Condition.not_empty(response_bytes, "response_bytes")

        cdef dict unpacked = MsgPackSerializer.deserialize(response_bytes)  # type: {str, bytes}

        cdef str response_type = unpacked[TYPE].decode(UTF8)
        cdef UUID correlation_id = UUID(unpacked[CORRELATION_ID].decode(UTF8))
        cdef UUID response_id = UUID(unpacked[ID].decode(UTF8))
        cdef datetime response_timestamp = convert_string_to_datetime(unpacked[TIMESTAMP].decode(UTF8))

        if response_type == Connected.__name__:
            return Connected(
                unpacked[MESSAGE].decode(UTF8),
                ServerId(unpacked[SERVER_ID].decode(UTF8)),
                SessionId(unpacked[SESSION_ID].decode(UTF8)),
                correlation_id,
                response_id,
                response_timestamp)
        elif response_type == Disconnected.__name__:
            return Disconnected(
                unpacked[MESSAGE].decode(UTF8),
                ServerId(unpacked[SERVER_ID].decode(UTF8)),
                SessionId(unpacked[SESSION_ID].decode(UTF8)),
                correlation_id,
                response_id,
                response_timestamp)
        elif response_type == MessageReceived.__name__:
            return MessageReceived(
                unpacked[RECEIVED_TYPE].decode(UTF8),
                correlation_id,
                response_id,
                response_timestamp)
        elif response_type == MessageRejected.__name__:
            return MessageRejected(
                unpacked[MESSAGE].decode(UTF8),
                correlation_id,
                response_id,
                response_timestamp)
        elif response_type == QueryFailure.__name__:
            return QueryFailure(
                unpacked[MESSAGE].decode(UTF8),
                correlation_id,
                response_id,
                response_timestamp)
        elif response_type == DataResponse.__name__:
            return DataResponse(
                unpacked[DATA],
                unpacked[DATA_TYPE].decode(UTF8),
                unpacked[DATA_ENCODING].decode(UTF8),
                correlation_id,
                response_id,
                response_timestamp)
        else:
            raise RuntimeError("Cannot deserialize response (unrecognized response).")


cdef class MsgPackLogSerializer(LogSerializer):
    """
    Provides a log message serializer for the MessagePack specification.
    """

    def __init__(self):
        """
        Initialize a new instance of the MsgPackLogSerializer class.
        """
        super().__init__()

    cpdef bytes serialize(self, LogMessage message):
        """
        Serialize the given log message to bytes.

        :param message: The message to serialize.
        :return bytes.
        """
        Condition.not_none(message, "message")

        cdef dict package = {
            TIMESTAMP: convert_datetime_to_string(message.timestamp),
            LOG_LEVEL: message.level_string(),
            LOG_TEXT: message.text,
            THREAD_ID: str(message.thread_id),
        }

        return MsgPackSerializer.serialize(package)

    cpdef LogMessage deserialize(self, bytes message_bytes):
        """
        Deserialize the given bytes to a response.

        :param message_bytes: The bytes to deserialize.
        :return LogMessage.
        """
        Condition.not_empty(message_bytes, "message_bytes")

        cdef dict unpacked = MsgPackSerializer.deserialize(message_bytes)

        return LogMessage(
            timestamp=convert_string_to_datetime(unpacked[TIMESTAMP].decode(UTF8)),
            level=log_level_from_string(unpacked[LOG_LEVEL].decode(UTF8)),
            text=unpacked[LOG_TEXT].decode(UTF8),
            thread_id=int(unpacked[THREAD_ID].decode(UTF8)))
