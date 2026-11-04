# Organization / Economy boundary

`mz_org` owns Organization identity, membership, grades, permissions, salary configuration, duty and payroll eligibility.

`mz_org` does not own or write money. Its account bridge validates the active Organization and contextual capability, then calls `mz_economy`. Payroll collects the eligible membership/grade/salary/duty data and asks `mz_economy` to execute the financial operation.

`mz_economy` owns Organization balances, deposit/withdraw, spend/refund receipts, idempotency, ledger and payroll debit/credit. Economy receives a typed Organization descriptor after authorization and does not read canonical Organization tables, avoiding a dependency cycle.

```text
mz_org (authorization + eligibility)
  -> mz_economy (financial execution)
       -> mz_core (Character identity + audit)
```

There is no SQL financial write in `mz_org`, no fallback to `mz_core`, and no dual-write.
