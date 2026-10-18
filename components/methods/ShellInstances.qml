pragma Singleton
import QtQuick

// Which axiom instances on a display keep running (InstanceManager): the
// newest, by launch time and then pid, so every instance decides the same.
// No processes: the caller lists the instances and ends them.
QtObject {
  id: root

  // What the instance with pid `self` does about `instances` (`qs list -j`'s
  // entries: { pid, launch_time }): { quit, end }. `quit` when a newer one
  // runs; else `end` lists the pids of the older ones
  function decide(instances, self) {
    const list = (instances ?? []).filter(instance => Number.isInteger(instance?.pid) && instance.pid > 0);
    if (list.length < 2)
      return {
        "quit": false,
        "end": []
      };
    const key = instance => [String(instance.launch_time ?? ""), instance.pid];
    const newer = (a, b) => {
      const [timeA, pidA] = key(a), [timeB, pidB] = key(b);
      return timeA !== timeB ? timeA > timeB : pidA > pidB;
    };
    const newest = list.reduce((best, instance) => newer(instance, best) ? instance : best);
    if (newest.pid !== self)
      return {
        "quit": list.some(instance => instance.pid === self),
        "end": []
      };
    return {
      "quit": false,
      "end": list.filter(instance => instance.pid !== self).map(instance => instance.pid)
    };
  }
}
