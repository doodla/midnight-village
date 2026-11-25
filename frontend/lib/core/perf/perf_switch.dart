import '../storage/tab_storage.dart';

/// Where this tab remembers that the recorder is on (`sessionStorage`): the
/// app's own navigation drops the query, and a reload must keep it.
const perfSwitchKey = 'mv.perf.v1';

/// Whether the recorder is on for this tab: `?perf=1` on the web address
/// switches it on and `?perf=0` off, each remembered for the tab; with
/// neither, what the tab remembers (off when it remembers nothing).
bool perfSwitchedOn(Map<String, String> query, TabStorage tab) {
  switch (query['perf']) {
    case '1':
      tab.write(perfSwitchKey, '1');
      return true;
    case '0':
      tab.remove(perfSwitchKey);
      return false;
  }
  return tab.read(perfSwitchKey) == '1';
}
