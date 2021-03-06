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

import numpy as np
import pytz

from cpython.datetime cimport datetime
from cpython.datetime cimport timedelta

from nautilus_trader.core.correctness cimport Condition

# Unix epoch is the UTC time at 00:00:00 on 1/1/1970
_UNIX_EPOCH = datetime(1970, 1, 1, 0, 0, 0, 0, tzinfo=pytz.utc)


cdef class Clock:
    """
    The base class for all clocks. All times are timezone aware UTC.
    """

    def __init__(self, UUIDFactory uuid_factory not None):
        """
        Initialize a new instance of the Clock class.

        :param uuid_factory: The uuid factory for the clocks time events.
        """
        self._log = None
        self._uuid_factory = uuid_factory
        self._timers = {}    # type: {str, Timer}
        self._handlers = {}  # type: {str, callable}
        self._stack = None
        self._default_handler = None

        self.timer_count = 0
        self.next_event_time = None
        self.next_event_name = None
        self.is_default_handler_registered = False

    cpdef datetime time_now(self):
        """
        Return the current datetime of the clock (UTC).

        :return datetime.
        """
        raise NotImplementedError("method must be implemented in the subclass")

    cpdef timedelta get_delta(self, datetime time):
        """
        Return the timedelta from the given time.

        :return timedelta.
        """
        Condition.not_none(time, "time")

        return self.time_now() - time

    cpdef Timer get_timer(self, str name):
        """
        Return the datetime for the given timer name (if found).
        """
        Condition.valid_string(name, "name")

        return self._timers[name]

    cpdef list get_timer_names(self):
        """
        Return the timer labels held by the clock.

        :return List[Label].
        """
        cdef str name
        return [name for name in self._timers.keys()]

    cpdef void register_default_handler(self, handler: callable) except *:
        """
        Register the given handler as the clocks default handler.

        :param handler: The handler to register (must be Callable).
        :raises TypeError: If handler is not of type callable.
        """
        self._default_handler = handler
        self.is_default_handler_registered = True

    cpdef void set_time_alert(
            self,
            str name,
            datetime alert_time,
            handler=None) except *:
        """
        Set a time alert for the given time. When the time is reached the
        handler will be passed the TimeEvent containing the timers unique label.

        :param name: The name for the alert (must be unique for this clock).
        :param alert_time: The time for the alert.
        :param handler: The optional handler to receive time events (must be Callable).
        :raises ValueError: If label is not unique for this clock.
        :raises ValueError: If alert_time is not >= the clocks current time.
        :raises TypeError: If handler is not of type Callable or None.
        :raises ValueError: If handler is None and no default handler is registered.
        """
        Condition.not_none(name, "name")
        Condition.not_none(alert_time, "alert_time")
        if handler is None:
            handler = self._default_handler
        Condition.not_in(name, self._timers, "name", "timers")
        Condition.not_in(name, self._handlers, "name", "timers")
        cdef datetime now = self.time_now()
        Condition.true(alert_time >= now, "alert_time >= time_now()")
        Condition.callable(handler, "handler")

        cdef Timer timer = self._get_timer(
            name=name,
            callback=handler,
            interval=alert_time - now,
            now=now,
            start_time=now,
            stop_time=alert_time)
        self._add_timer(timer, handler)

    cpdef void set_timer(
            self,
            str name,
            timedelta interval,
            datetime start_time=None,
            datetime stop_time=None,
            handler=None) except *:
        """
        Set a timer with the given interval. The timer will run from the start
        time (optionally until the stop time). When the intervals are reached the
        handlers will be passed the TimeEvent containing the timers unique label.

        :param name: The name for the timer (must be unique for this clock).
        :param interval: The time interval for the timer.
        :param start_time: The optional start time for the timer (if None then starts immediately).
        :param stop_time: The optional stop time for the timer (if None then repeats indefinitely).
        :param handler: The optional handler to receive time events (must be Callable or None).
        :raises ValueError: If label is not unique for this clock.
        :raises ValueError: If interval is not positive (> 0).
        :raises ValueError: If stop_time is not None and stop_time < time_now.
        :raises ValueError: If stop_time is not None and start_time + interval > stop_time.
        :raises TypeError: If handler is not of type Callable or None.
        :raises ValueError: If handler is None and no default handler is registered.
        """
        Condition.valid_string(name, "name")
        Condition.not_none(interval, "interval")
        if handler is None:
            handler = self._default_handler
        Condition.not_in(name, self._timers, "name", "timers")
        Condition.not_in(name, self._handlers, "name", "timers")
        Condition.true(interval.total_seconds() > 0, "interval positive")
        Condition.callable(handler, "handler")

        cdef datetime now = self.time_now()
        if start_time is None:
            start_time = now
        if stop_time is not None:
            Condition.true(stop_time > now, "stop_time > now")
            Condition.true(start_time + interval <= stop_time, "start_time + interval <= stop_time")

        cdef Timer timer = self._get_timer(
            name=name,
            interval=interval,
            callback=handler,
            now=now,
            start_time=start_time,
            stop_time=stop_time)
        self._add_timer(timer, handler)

    cpdef void cancel_timer(self, str name) except *:
        """
        Cancel the timer corresponding to the given label.

        :param name: The name for the timer to cancel.
        :raises RuntimeError: If no timer with the given name is found.
        """
        Condition.valid_string(name, "name")

        cdef Timer timer = self._timers.pop(name, None)
        if timer is None:
            self._log.warning(f"Cannot cancel timer (no timer found with name '{name}').")
            return

        timer.cancel()
        self._handlers.pop(name, None)
        self._remove_timer(timer)

    cpdef void cancel_all_timers(self) except *:
        """
        Cancel all timers inside the clock.
        """
        cdef str name
        for name in self.get_timer_names():
            # Using a list of timer names as cancel_timer handles the clean
            # removal of both the handler and timer.
            self.cancel_timer(name)

    cdef Timer _get_timer(
            self,
            str name,
            callback,
            timedelta interval,
            datetime now,
            datetime start_time,
            datetime stop_time):
        raise NotImplementedError("method must be implemented in the subclass")

    cdef void _add_timer(self, Timer timer, handler) except *:
        self._timers[timer.name] = timer
        self._handlers[timer.name] = handler
        self._update_stack()
        self._update_timing()

    cdef void _remove_timer(self, Timer timer) except *:
        self._timers.pop(timer.name, None)
        self._handlers.pop(timer.name, None)
        self._update_stack()
        self._update_timing()

    cdef void _update_stack(self) except *:
        self.timer_count = len(self._timers)

        if self.timer_count > 0:
            self._stack = np.asarray(list(self._timers.values()))
        else:
            self._stack = None

    cdef void _update_timing(self) except *:
        if self.timer_count == 0:
            self.next_event_time = None
            return
        elif self.timer_count == 1:
            self.next_event_time = self._stack[0].next_time
            return

        cdef datetime next_time = self._stack[0].next_time
        cdef datetime observed
        cdef int i
        for i in range(self.timer_count - 1):
            observed = self._stack[i + 1].next_time
            if observed < next_time:
                next_time = observed

        self.next_event_time = next_time
