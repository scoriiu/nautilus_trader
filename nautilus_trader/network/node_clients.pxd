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

from nautilus_trader.common.clock cimport Clock
from nautilus_trader.common.logging cimport LoggerAdapter
from nautilus_trader.common.timer cimport TimeEvent
from nautilus_trader.common.uuid cimport UUIDFactory
from nautilus_trader.core.message cimport Message
from nautilus_trader.core.message cimport MessageType
from nautilus_trader.core.message cimport Request
from nautilus_trader.core.uuid cimport UUID
from nautilus_trader.network.compression cimport Compressor
from nautilus_trader.network.identifiers cimport ClientId
from nautilus_trader.network.identifiers cimport SessionId
from nautilus_trader.network.queue cimport MessageQueueInbound
from nautilus_trader.network.queue cimport MessageQueueOutbound
from nautilus_trader.network.socket cimport ClientSocket
from nautilus_trader.network.socket cimport SubscriberSocket
from nautilus_trader.serialization.base cimport DictionarySerializer
from nautilus_trader.serialization.base cimport RequestSerializer
from nautilus_trader.serialization.base cimport ResponseSerializer


cdef class ClientNode:
    cdef Clock _clock
    cdef UUIDFactory _uuid_factory
    cdef LoggerAdapter _log
    cdef Compressor _compressor
    cdef object _message_handler

    cdef readonly ClientId client_id
    cdef readonly int sent_count
    cdef readonly int recv_count

    cpdef void register_handler(self, handler) except *
    cpdef bint is_connected(self)
    cpdef void connect(self) except *
    cpdef void disconnect(self) except *
    cpdef void dispose(self) except *


cdef class MessageClient(ClientNode):
    cdef ClientSocket _socket_outbound
    cdef ClientSocket _socket_inbound
    cdef MessageQueueOutbound _queue_outbound
    cdef MessageQueueInbound _queue_inbound
    cdef DictionarySerializer _header_serializer
    cdef RequestSerializer _request_serializer
    cdef ResponseSerializer _response_serializer
    cdef dict _awaiting_reply

    cdef readonly SessionId session_id

    cpdef void send_request(self, Request request) except *
    cpdef void send_string(self, str message) except *
    cpdef void send_message(self, Message message, bytes body) except *
    cdef void _send(self, MessageType message_type, str class_name, bytes body) except *
    cpdef void _check_connection(self, TimeEvent event) except *
    cpdef void _recv_frames(self, list frames) except *
    cdef void _register_message(self, Message message, int retry=*) except *
    cdef void _deregister_message(self, UUID correlation_id, int retry=*) except *


cdef class MessageSubscriber(ClientNode):
    cdef SubscriberSocket _socket
    cdef MessageQueueInbound _queue

    cpdef void subscribe(self, str topic) except *
    cpdef void unsubscribe(self, str topic) except *
    cpdef void _recv_frames(self, list frames) except *
    cpdef void _no_subscriber_handler(self, str topic, bytes body) except *
