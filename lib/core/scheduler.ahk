class scheduler {
	static tasks := Map()
	static timer_fn := 0
	static interval := 0
	static running := false

	static start(interval_ms := unset) {
		if IsSet(interval_ms)
			this.interval := interval_ms
		else if (this.interval == 0)
			this.interval := this.compute_min_interval(10)
		if !this.timer_fn
			this.timer_fn := ObjBindMethod(this, "tick")
		SetTimer(this.timer_fn, this.interval)
		this.running := true
	}

	static stop() {
		if this.timer_fn
			SetTimer(this.timer_fn, 0)
		this.running := false
	}

	static add(name, fn, interval_ms, enable_fn := 0) {
		if !(interval_ms > 0)
			interval_ms := 10
		if this.tasks.Has(name) {
			task := this.tasks[name]
			task.fn := fn
			task.interval := interval_ms
			task.enabled := enable_fn
		} else {
			this.tasks[name] := { fn: fn, interval: interval_ms, enabled: enable_fn, last: 0 }
		}
		this.update_base_interval()
	}

	static remove(name) {
		if this.tasks.Has(name)
			this.tasks.Delete(name)
		this.update_base_interval()
	}

	static compute_min_interval(fallback := 10) {
		min := 0
		for name, task in this.tasks {
			if (min == 0 || task.interval < min)
				min := task.interval
		}
		return (min == 0 ? fallback : min)
	}

	static update_base_interval() {
		min := this.compute_min_interval(this.interval ? this.interval : 10)
		if (min != this.interval) {
			this.interval := min
			if this.timer_fn && this.running
				SetTimer(this.timer_fn, this.interval)
		}
	}

	static tick(*) {
		now := A_TickCount
		for name, task in this.tasks {
			if (now - task.last < task.interval)
				continue
			if (task.enabled && !task.enabled.Call())
				continue
			task.last := now
			try task.fn()
		}
	}
}