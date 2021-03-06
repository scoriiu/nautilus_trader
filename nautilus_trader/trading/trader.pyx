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

from nautilus_trader.analysis.performance cimport PerformanceAnalyzer
from nautilus_trader.analysis.reports cimport ReportProvider
from nautilus_trader.common.component cimport create_component_fsm
from nautilus_trader.common.data cimport DataClient
from nautilus_trader.common.execution cimport ExecutionEngine
from nautilus_trader.common.logging cimport Logger
from nautilus_trader.common.logging cimport LoggerAdapter
from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.core.fsm cimport InvalidStateTrigger
from nautilus_trader.model.c_enums.component_state cimport ComponentState
from nautilus_trader.model.c_enums.component_state cimport component_state_to_string
from nautilus_trader.model.commands cimport AccountInquiry
from nautilus_trader.trading.strategy cimport TradingStrategy


cdef class Trader:
    """
    Provides a trader for managing a portfolio of trading strategies.
    """

    def __init__(self,
                 TraderId trader_id not None,
                 AccountId account_id not None,
                 list strategies not None,
                 DataClient data_client not None,
                 ExecutionEngine exec_engine not None,
                 Clock clock not None,
                 UUIDFactory uuid_factory not None,
                 Logger logger not None):
        """
        Initialize a new instance of the Trader class.

        :param trader_id: The trader_id for the trader.
        :param account_id: The account_id for the trader.
        :param strategies: The initial strategies for the trader.
        :param data_client: The data client to register the traders strategies with.
        :param exec_engine: The execution engine to register the traders strategies with trader.
        :param clock: The clock for the trader.
        :param uuid_factory: The uuid_factory for the trader.
        :param logger: The logger for the trader.
        :raises ValueError: If strategies is None.
        :raises ValueError: If strategies list is empty.
        :raises TypeError: If strategies list contains a type other than TradingStrategy.
        :raises ValueError: If trader_id is not equal to the exec_engine.trader_id.
        :raises ValueError: If account_id is not equal to the exec_engine.account_id.
        """
        Condition.equal(trader_id, exec_engine.trader_id, "trader_id", "exec_engine.trader_id")
        Condition.equal(account_id, exec_engine.account_id, "account_id", "exec_engine.account_id")

        self._clock = clock
        self._uuid_factory = uuid_factory
        self.id = trader_id
        self.account_id = account_id
        self._log = LoggerAdapter(f"Trader-{self.id.value}", logger)
        self._data_client = data_client
        self._exec_engine = exec_engine
        self._report_provider = ReportProvider()

        self.portfolio = self._exec_engine.portfolio
        self.analyzer = PerformanceAnalyzer()

        self._fsm = create_component_fsm()

        self.strategies = []
        self.strategy_ids = set()
        self.initialize_strategies(strategies)

    cpdef void initialize_strategies(self, list strategies: [TradingStrategy]) except *:
        """
        Change strategies with the given list of trading strategies.

        :param strategies: The list of strategies to load into the trader.
        :raises ValueError: If strategies is None.
        :raises ValueError: If strategies is empty.
        :raises TypeError: If strategies contains a type other than TradingStrategy.
        """
        Condition.not_empty(strategies, "strategies")
        Condition.list_type(strategies, TradingStrategy, "strategies")

        if self._fsm.state == ComponentState.RUNNING:
            self._log.error("Cannot re-initialize the strategies of a running trader.")
            return

        self._log.info(f"Initializing strategies...")

        cdef TradingStrategy strategy
        for strategy in self.strategies:
            # Design assumption that no strategies are running
            assert not strategy.state() == ComponentState.RUNNING

        # Dispose of current strategies
        for strategy in self.strategies:
            self._exec_engine.deregister_strategy(strategy)
            strategy.dispose()

        self.strategies.clear()
        self.strategy_ids.clear()

        # Initialize strategies
        for strategy in strategies:
            # Check strategy_ids are unique
            if strategy.id not in self.strategy_ids:
                self.strategy_ids.add(strategy.id)
            else:
                raise ValueError(f"The strategy_id {strategy.id} was not unique "
                                 f"(duplicate strategy_ids).")

            # Wire trader into strategy
            strategy.register_trader(
                self.id,
                self._clock.__class__(),  # Clock per strategy
                self._uuid_factory,
                self._log.get_logger())

            # Wire data client into strategy
            self._data_client.register_strategy(strategy)

            # Wire execution engine into strategy
            self._exec_engine.register_strategy(strategy)

            # Add to internal strategies
            self.strategies.append(strategy)

            self._log.info(f"Initialized {strategy}.")

    cpdef void start(self) except *:
        """
        Start the trader.
        """
        try:
            self._fsm.trigger('START')
        except InvalidStateTrigger as ex:
            self._log.exception(ex)
            self.stop()  # Do not start trader in an invalid state
            return

        self._log.info(f"state={self._fsm.state_as_string()}...")

        if not self.strategies:
            self._log.error(f"Cannot start trader (no strategies loaded).")
            return

        self.account_inquiry()

        for strategy in self.strategies:
            strategy.start()

        self._fsm.trigger('RUNNING')
        self._log.info(f"state={self._fsm.state_as_string()}.")

    cpdef void stop(self) except *:
        """
        Stop the trader.
        """
        try:
            self._fsm.trigger('STOP')
        except InvalidStateTrigger as ex:
            self._log.exception(ex)
            return

        self._log.info(f"state={self._fsm.state_as_string()}...")

        for strategy in self.strategies:
            if strategy.state() == ComponentState.RUNNING:
                strategy.stop()
            else:
                self._log.warning(f"{strategy} already stopped.")

        self._fsm.trigger('STOPPED')
        self._log.info(f"state={self._fsm.state_as_string()}.")

    cpdef void check_residuals(self) except *:
        """
        Check for residual business objects such as working orders or open positions.
        """
        self._exec_engine.check_residuals()

    cpdef void save(self) except *:
        """
        Save all strategy states to the execution database.
        """
        for strategy in self.strategies:
            self._exec_engine.database.update_strategy(strategy)

    cpdef void load(self) except *:
        """
        Load all strategy states from the execution database.
        """
        for strategy in self.strategies:
            self._exec_engine.database.load_strategy(strategy)

    cpdef void reset(self) except *:
        """
        Reset the trader.

        All stateful values of the portfolio, and every strategy are reset.

        Note: The trader cannot be running otherwise an error is logged.
        """
        try:
            self._fsm.trigger('RESET')
        except InvalidStateTrigger as ex:
            self._log.exception(ex)
            return

        self._log.info(f"state={self._fsm.state_as_string()}...")

        for strategy in self.strategies:
            strategy.reset()

        self.portfolio.reset()
        self.analyzer.reset()

        self._fsm.trigger('RESET')
        self._log.info(f"state={self._fsm.state_as_string()}.")

    cpdef void dispose(self) except *:
        """
        Dispose of the trader.

        Disposes all internally held strategies.
        """
        try:
            self._fsm.trigger('DISPOSE')
        except InvalidStateTrigger as ex:
            self._log.exception(ex)
            return

        self._log.info(f"state={self._fsm.state_as_string()}...")

        for strategy in self.strategies:
            strategy.dispose()

        self._fsm.trigger('DISPOSED')
        self._log.info(f"state={self._fsm.state_as_string()}.")

    cpdef void account_inquiry(self) except *:
        """
        Send an AccountInquiry command to the execution service.
        """
        cdef AccountInquiry command = AccountInquiry(
            trader_id=self.id,
            account_id=self.account_id,
            command_id=self._uuid_factory.generate(),
            command_timestamp=self._clock.time_now())

        self._exec_engine.execute_command(command)

    cpdef ComponentState state(self):
        """
        Return the traders state.
        """
        return self._fsm.state

    cpdef dict strategy_states(self):
        """
        Return a dictionary containing the traders strategy status.
        The key is the strategy_id.
        The value is a bool which is True if the strategy is running else False.

        :return Dict[StrategyId, bool].
        """
        cdef states = {}
        for strategy in self.strategies:
            states[strategy.id] = component_state_to_string(strategy.state())

        return states

    cpdef object generate_orders_report(self):
        """
        Return an orders report.

        :return pd.DataFrame.
        """
        return self._report_provider.generate_orders_report(self._exec_engine.database.get_orders())

    cpdef object generate_order_fills_report(self):
        """
        Return an order fills report.

        :return pd.DataFrame.
        """
        return self._report_provider.generate_order_fills_report(self._exec_engine.database.get_orders())

    cpdef object generate_positions_report(self):
        """
        Return a positions report.

        :return pd.DataFrame.
        """
        return self._report_provider.generate_positions_report(self._exec_engine.database.get_positions())

    cpdef object generate_account_report(self):
        """
        Return an account report.

        :return pd.DataFrame.
        """
        return self._report_provider.generate_account_report(self._exec_engine.account.get_events())
