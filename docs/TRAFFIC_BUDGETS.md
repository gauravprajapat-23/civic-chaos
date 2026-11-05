# CC-036 Traffic AI and physics budgets

CivicTrafficBudget implements deterministic round-robin decision selection, staggered sensor schedules, bounded cached readings and a rolling 120-sample execution-time window. Configure the agent cap, decision cap and sensor interval explicitly. The spawner enforces the agent cap and records traffic fixed-step execution times in microseconds, exposed through metrics(). All vehicle motion and collision-relevant lead sensing still run each simulation tick; stale sensor readings must not replace safety-critical observations.

The round-robin selector is an API for future utility AI integration; the live traffic spawner does not currently invoke it. No target-device frame-time guarantee can be claimed without Android profiling. Run the headless test tests/traffic_budget_test.gd and measure real device timings at multiple traffic densities.
