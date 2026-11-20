# Night2

TLC reached 2,533,694 states, more than the chart budget of 500, so the command wrote no chart.mmd.

## Rules that hold
ChooseLimit, AppliedAtMostOnce, AppliedExactlyOnce, LockedVoteKept, NoDeadlock

## Rules not checked
PhaseForward, ReachesResults
TLC stopped with exit 1 before it checked these rules:
```
Error: when writing the disk (StatePoolWriter.run):
Cannot invoke "tlc2.value.impl.FcnRcdValue.write(tlc2.value.IValueOutputStream)" because "this.fcnRcd" is null
```
