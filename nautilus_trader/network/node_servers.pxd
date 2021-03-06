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
from nautilus_trader.common.uuid cimport UUIDFactory
from nautilus_trader.core.message cimport Message
from nautilus_trader.core.message cimport MessageType
from nautilus_trader.core.uuid cimport UUID
from nautilus_trader.network.compression cimport Compressor
from nautilus_trader.network.identifiers cimport ClientId
from nautilus_trader.network.identifiers cimport ServerId
from nautilus_trader.network.messages cimport Connect
from nautilus_trader.network.messages cimport Disconnect
from nautilus_trader.network.messages cimport Response
from nautilus_trader.network.queue cimport MessageQueueInbound
from nautilus_trader.network.queue cimport MessageQueueOutbound
from nautilus_trader.network.socket cimport ServerSocket
from nautilus_trader.serialization.base cimport DictionarySerializer
from nautilus_trader.serialization.base cimport RequestSerializer
from nautilus_trader.serialization.base cimport ResponseSerializer


cdef class ServerNode:
    cdef Clock _clock
    cdef UUIDFactory _uuid_factory
    cdef LoggerAdapter _log
    cdef Compressor _compressor

    cdef readonly ServerId server_id
    cdef readonly int sent_count
    cdef readonly int recv_count

    cpdef void start(self) except *
    cpdef void stop(self) except *
    cpdef void dispose(self) except *

cdef class MessageServer(ServerNode):
    cdef ServerSocket _socket_outbound
    cdef ServerSocket _socket_inbound
    cdef MessageQueueOutbound _queue_outbound
    cdef MessageQueueInbound _queue_inbound
    cdef DictionarySerializer _header_serializer
    cdef RequestSerializer _request_serializer
    cdef ResponseSerializer _response_serializer
    cdef object _thread
    cdef dict _peers
    cdef dict _handlers

    cpdef void register_request_handler(self, handler) except *
    cpdef void register_handler(self, MessageType message_type, handler) except *
    cpdef void send_rejected(self, str rejected_message, UUID correlation_id, ClientId receiver) except *
    cpdef void send_received(self, Message original, ClientId receiver) except *
    cpdef void send_response(self, Response response, ClientId receiver) except *
    cpdef void send_string(self, str message, ClientId receiver) except *
    cdef void _send(self, ClientId receiver, dict header, bytes body) except *
    cpdef void _recv_frames(self, list frames) except *
    cdef void _handle_request(self, bytes body, ClientId sender) except *
    cdef void _handle_connection(self, Connect request) except *
    cdef void _handle_disconnection(self, Disconnect request) except *


cdef class MessagePublisher(ServerNode):
    cdef ServerSocket _socket
    cdef MessageQueueOutbound _queue

    cpdef void publish(self, str topic, bytes message) except *
