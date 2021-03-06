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

import zmq

from cpython.datetime cimport datetime
from cpython.datetime cimport timedelta

from nautilus_trader.common.clock cimport Clock
from nautilus_trader.common.timer cimport TimeEvent
from nautilus_trader.common.uuid cimport UUIDFactory
from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.core.message cimport Message
from nautilus_trader.core.message cimport MessageType
from nautilus_trader.core.message cimport message_type_from_string
from nautilus_trader.core.message cimport message_type_to_string
from nautilus_trader.core.uuid cimport UUID
from nautilus_trader.network.compression cimport Compressor
from nautilus_trader.network.encryption cimport EncryptionSettings
from nautilus_trader.network.messages cimport Connect
from nautilus_trader.network.messages cimport Connected
from nautilus_trader.network.messages cimport Disconnect
from nautilus_trader.network.messages cimport Disconnected
from nautilus_trader.network.messages cimport Request
from nautilus_trader.network.messages cimport Response
from nautilus_trader.network.queue cimport MessageQueueInbound
from nautilus_trader.network.queue cimport MessageQueueOutbound
from nautilus_trader.network.socket cimport ClientSocket
from nautilus_trader.serialization.base cimport DictionarySerializer
from nautilus_trader.serialization.base cimport RequestSerializer
from nautilus_trader.serialization.base cimport ResponseSerializer
from nautilus_trader.serialization.constants cimport *


cdef str _IS_CONNECTED = "_is_connected?"
cdef str _IS_DISCONNECTED = "_is_disconnected?"


cdef class ClientNode:
    """
    The base class for all client nodes.
    """

    def __init__(
            self,
            ClientId client_id not None,
            Compressor compressor not None,
            Clock clock not None,
            UUIDFactory uuid_factory not None,
            LoggerAdapter logger not None):
        """
        Initialize a new instance of the ClientNode class.

        :param client_id: The client identifier.
        :param compressor: The message compressor.
        :param clock: The clock for the component.
        :param uuid_factory: The uuid factory for the component.
        :param logger: The logger for the component.
        :raises ValueError: If the host is not a valid string.
        :raises ValueError: If the port is not in range [49152, 65535].
        """
        self._compressor = compressor
        self._clock = clock
        self._uuid_factory = uuid_factory
        self._log = logger
        self._message_handler = None

        self.client_id = client_id
        self.sent_count = 0
        self.recv_count = 0

    cpdef void register_handler(self, handler: callable) except *:
        """
        Register a handler to receive messages.

        Parameters
        ----------
        handler : callable
            The handler to register.
        """
        Condition.callable(handler, "handler")

        if self._message_handler is not None:
            self._log.debug(f"Registered message handler {handler} by replacing {self._message_handler}.")
        else:
            self._log.debug(f"Registered message handler {handler}.")

        self._message_handler = handler

    cpdef bint is_connected(self):
        raise NotImplementedError("method must be implemented in the subclass")

    cpdef void connect(self) except *:
        raise NotImplementedError("method must be implemented in the subclass")

    cpdef void disconnect(self) except *:
        raise NotImplementedError("method must be implemented in the subclass")

    cpdef void dispose(self) except *:
        raise NotImplementedError("method must be implemented in the subclass")


cdef class MessageClient(ClientNode):
    """
    Provides an asynchronous messaging client.
    """

    def __init__(
            self,
            ClientId client_id not None,
            str server_host not None,
            int server_req_port,
            int server_res_port,
            DictionarySerializer header_serializer not None,
            RequestSerializer request_serializer not None,
            ResponseSerializer response_serializer not None,
            Compressor compressor not None,
            EncryptionSettings encryption not None,
            Clock clock not None,
            UUIDFactory uuid_factory not None,
            LoggerAdapter logger not None):
        """
        Initialize a new instance of the MessageClient class.

        :param client_id: The client identifier for the worker.
        :param server_host: The server host address.
        :param server_req_port: The server request port.
        :param server_res_port: The server response port.
        :param header_serializer: The header serializer.
        :param request_serializer: The request serializer.
        :param response_serializer: The response serializer.
        :param compressor: The message compressor.
        :param encryption: The encryption configuration.
        :param clock: The clock for the component.
        :param uuid_factory: The uuid factory for the component.
        :param logger: The logger for the component.
        :raises ValueError: If the host is not a valid string.
        :raises ValueError: If the server_req_port is not in range [49152, 65535].
        :raises ValueError: If the server_res_port is not in range [49152, 65535].
        """
        Condition.valid_string(server_host, "server_host")
        Condition.valid_port(server_req_port, "server_in_port")
        Condition.valid_port(server_res_port, "server_out_port")
        super().__init__(
            client_id,
            compressor,
            clock,
            uuid_factory,
            logger)

        self._socket_outbound = ClientSocket(
            client_id,
            server_host,
            server_req_port,
            zmq.DEALER,  # noqa (zmq reference)
            encryption,
            self._log)

        self._socket_inbound = ClientSocket(
            client_id,
            server_host,
            server_res_port,
            zmq.DEALER,  # noqa (zmq reference)
            encryption,
            self._log)

        self._queue_outbound = MessageQueueOutbound(
            self._socket_outbound,
            self._log)

        expected_frames = 2  # [header, body]
        self._queue_inbound = MessageQueueInbound(
            expected_frames,
            self._socket_inbound,
            self._recv_frames,
            self._log)

        self._header_serializer = header_serializer
        self._request_serializer = request_serializer
        self._response_serializer = response_serializer
        self._message_handler = None
        self._awaiting_reply = {}  # type: {UUID, Message}

        self.session_id = None

    cpdef bint is_connected(self):
        """
        Return a value indicating whether the client is connected to the server.
        """
        return self.session_id is not None

    cpdef void connect(self) except *:
        """
        Connect to the server.
        """
        self._socket_outbound.connect()
        self._socket_inbound.connect()

        cdef datetime timestamp = self._clock.time_now()

        cdef Connect connect = Connect(
            self.client_id,
            SessionId.create(self.client_id, timestamp, "None").value,
            self._uuid_factory.generate(),
            timestamp)

        # Set check connected alert
        self._clock.set_time_alert(
            connect.id.value + _IS_CONNECTED,
            timestamp + timedelta(seconds=2),
            self._check_connection)

        self.send_message(connect, self._request_serializer.serialize(connect))

    cpdef void disconnect(self) except *:
        """
        Disconnect from the server.
        """
        if not self.is_connected():
            self._log.warning("No session to disconnect from.")
            return

        cdef datetime timestamp = self._clock.time_now()

        cdef Disconnect disconnect = Disconnect(
            self.client_id,
            self.session_id,
            self._uuid_factory.generate(),
            timestamp)

        # Set check disconnected alert
        self._clock.set_time_alert(
            disconnect.id.value + _IS_DISCONNECTED,
            timestamp + timedelta(seconds=2),
            self._check_connection)

        self.send_message(disconnect, self._request_serializer.serialize(disconnect))

    cpdef void dispose(self) except *:
        """
        Dispose of the MQWorker which close the socket (call disconnect first).
        """
        self._socket_outbound.dispose()
        self._socket_inbound.dispose()
        self._log.debug(f"Disposed.")

    cpdef void send_request(self, Request request) except *:
        """
        Send the given request.

        Parameters
        ----------
        request : Request
            The request to send.
        """
        self.send_message(request, self._request_serializer.serialize(request))

    cpdef void send_string(self, str message) except *:
        """
        Send the given string message. Note that a reply will not be awaited as
        there is no correlation identifier.

        Parameters
        ----------
        message : str
        """
        self._send(MessageType.STRING, UTF8, message.encode(UTF8))

    cpdef void send_message(self, Message message, bytes body) except *:
        """
        Send the given message to the server.

        Parameters
        ----------
        message : Message
            The message to send.
        body : bytes
            The serialized message body.
        """
        Condition.not_none(message, "message")

        self._register_message(message)

        self._log.debug(f"[{self.sent_count}]--> {message}")
        self._send(message.message_type, message.__class__.__name__, body)

    cdef void _send(self, MessageType message_type, str class_name, bytes body) except *:
        Condition.not_equal(message_type, MessageType.UNDEFINED, "message_type", "UNDEFINED")
        Condition.valid_string(class_name, "class_name")
        Condition.not_empty(body, "body")

        cdef dict header = {
            MESSAGE_TYPE: message_type_to_string(message_type).title(),
            TYPE: class_name
        }

        # Compress frames
        cdef bytes frame_header = self._compressor.compress(self._header_serializer.serialize(header))
        cdef bytes frame_body = self._compressor.compress(body)

        self._queue_outbound.send([frame_header, frame_body])
        self._log.verbose(f"[{self.sent_count}]--> header={header}, body={len(frame_body)} bytes")
        self.sent_count += 1

    cpdef void _recv_frames(self, list frames) except *:
        self.recv_count += 1

        # Decompress frames
        cdef bytes frame_header = self._compressor.decompress(frames[0])
        cdef bytes frame_body = self._compressor.decompress(frames[1])

        cdef dict header = self._header_serializer.deserialize(frame_header)

        cdef MessageType message_type = message_type_from_string(header[MESSAGE_TYPE].upper())
        if message_type == MessageType.STRING:
            message = frame_body.decode(UTF8)
            self._log.verbose(f"<--[{self.recv_count}] '{message}'")
            if self._message_handler is not None:
                self._message_handler(message)
            return

        self._log.verbose(f"<--[{self.recv_count}] header={header}, body={len(frame_body)} bytes")

        if message_type != MessageType.RESPONSE:
            self._log.error(f"Not a valid response, was {header[MESSAGE_TYPE]}")
            return

        cdef Response response = self._response_serializer.deserialize(frame_body)
        self._log.debug(f"<--[{self.recv_count}] {response}")
        self._deregister_message(response.correlation_id)

        if isinstance(response, Connected):
            if self.session_id is not None:
                self._log.warning(response.message)
            else:
                self._log.info(response.message)
            self.session_id = response.session_id
            return
        elif isinstance(response, Disconnected):
            if self.session_id is None:
                self._log.warning(response.message)
            else:
                self._log.info(response.message)
            self.session_id = None
            self._socket_outbound.disconnect()
            self._socket_inbound.disconnect()
        else:
            if self._message_handler is not None:
                self._message_handler(response)

    cpdef void _check_connection(self, TimeEvent event) except *:
        if event.name.endswith(_IS_CONNECTED):
            if not self.is_connected():
                self._log.warning("Connection request timed out...")
        elif event.name.endswith(_IS_DISCONNECTED):
            if self.is_connected():
                self._log.warning(f"Session {self.session_id} is still connected...")
        else:
            self._log.error(f"Check connection message '{event.name}' not recognized.")

    cdef void _register_message(self, Message message, int retry=0) except *:
        try:
            if retry < 3:
                self._awaiting_reply[message.id] = message
                self._log.verbose(f"Registered message with id {message.id.value} to await reply.")
            else:
                self._log.error(f"Could not register {message} to await reply, retries={retry}.")
        except RuntimeError as ex:
            retry += 1
            self._register_message(message, retry)

    cdef void _deregister_message(self, UUID correlation_id, int retry=0) except *:
        cdef Message message
        try:
            if retry < 3:
                message = self._awaiting_reply.pop(correlation_id, None)
                if message is None:
                    self._log.error(f"No awaiting message for correlation id {correlation_id}.")
                else:
                    self._log.verbose(f"Received reply for message with id {message.id.value}.")
                    pass
            else:
                self._log.error(f"Could not deregister with correlation id {correlation_id}, retries={retry}.")
        except RuntimeError as ex:
            retry += 1
            self._deregister_message(message, retry)


cdef class MessageSubscriber(ClientNode):
    """
    Provides an asynchronous messaging subscriber.
    """

    def __init__(
            self,
            ClientId client_id,
            str host,
            int port,
            Compressor compressor not None,
            EncryptionSettings encryption not None,
            Clock clock not None,
            UUIDFactory uuid_factory not None,
            LoggerAdapter logger):
        """
        Initialize a new instance of the MessageSubscriber class.

        :param client_id: The client identifier for the worker.
        :param host: The service host address.
        :param port: The service port.
        :param compressor: The The message compressor.
        :param encryption: The encryption configuration.
        :param clock: The clock for the component.
        :param uuid_factory: The uuid factory for the component.
        :param logger: The logger for the component.
        :raises ValueError: If the service_name is not a valid string.
        :raises ValueError: If the port is not in range [0, 65535].
        :raises ValueError: If the topic is not a valid string.
        """
        Condition.valid_string(host, "host")
        Condition.valid_port(port, "port")
        super().__init__(
            client_id,
            compressor,
            clock,
            uuid_factory,
            logger)

        self.register_handler(self._no_subscriber_handler)

        self._socket = SubscriberSocket(
            client_id,
            host,
            port,
            encryption,
            self._log)

        expected_frames = 2  # [topic, body]
        self._queue = MessageQueueInbound(
            expected_frames,
            self._socket,
            self._recv_frames,
            self._log)

    cpdef bint is_connected(self):
        return True  # TODO: Keep alive heartbeat polling

    cpdef void connect(self) except *:
        """
        Connect to the publisher.
        """
        self._socket.connect()

    cpdef void disconnect(self) except *:
        """
        Disconnect from the publisher.
        """
        self._socket.disconnect()

    cpdef void dispose(self) except *:
        """
        Dispose of the client (call disconnect first).
        """
        self._socket.dispose()
        self._log.debug(f"Disposed.")

    cpdef void subscribe(self, str topic) except *:
        """
        Subscribe the client to the given topic.

        :param topic: The topic to subscribe to.
        """
        Condition.valid_string(topic, "topic")

        self._socket.subscribe(topic)

    cpdef void unsubscribe(self, str topic) except *:
        """
        Unsubscribe the client from the given topic.

        :param topic: The topic to unsubscribe from.
        """
        Condition.valid_string(topic, "topic")

        self._socket.unsubscribe(topic)

    cpdef void _recv_frames(self, list frames) except *:
        cdef str topic = frames[0].decode(UTF8)
        cdef bytes body = self._compressor.decompress(frames[1])

        self._message_handler(topic, body)
        self.recv_count += 1

    cpdef void _no_subscriber_handler(self, str topic, bytes body) except *:
        self._log.warning(f"Received message from topic {topic} with no handler registered.")
