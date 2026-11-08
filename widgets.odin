package muw

import "base:intrinsics"
import "core:reflect"

import ln "core:math/linalg"

import mu "vendor:microui"

Picker_Type :: enum {
	Slider,
	Number,
}

mu_numeric_raw :: proc(
	ctx: ^mu.Context,
	label: string,
	val: ^$T,
	low, high: T,
	step: T,
	kind: Picker_Type,
) -> (
	res: mu.Result_Set,
) where intrinsics.type_is_numeric(T) {
	mu.push_id(ctx, uintptr(val)); defer mu.pop_id(ctx)

	s := step
	format := mu.SLIDER_FMT
	when intrinsics.type_is_unsigned(T) {
		if s == 0 do s = 1
		format = "%.0f"
	}

	@(static) tmp: f32
	tmp = f32(val^)
	switch kind {
	case .Slider:
		res = mu.slider(ctx, &tmp, f32(low), f32(high), f32(s), format)
	case .Number:
		res = mu.number(ctx, &tmp, f32(s), format)
	}
	if kind == .Number do tmp = clamp(tmp, f32(low), f32(high))
	val^ = T(tmp)
	return
}

mu_numeric :: proc(
	ctx: ^mu.Context,
	label: string,
	val: ^$T,
	low, high: T,
	step: T = 1,
	kind: Picker_Type = .Number,
) -> (
	res: mu.Result_Set,
) where intrinsics.type_is_numeric(T) {
	if label != "" {
		label_width := ctx.text_width(ctx.style.font, label) + ctx.style.padding * 2
		mu.layout_row(ctx, {label_width, -1})
		mu.label(ctx, label)
	} else {
		mu.layout_row(ctx, {-1})
	}
	return mu_numeric_raw(ctx, label, val, low, high, step, kind)
}

mu_color :: proc(
	ctx: ^mu.Context,
	label: string,
	v: ^$T/[$N]$E,
	low, high: E,
	step: E = 0,
	kind: Picker_Type = .Number,
) -> (
	res: mu.Result_Set,
) where E == u8 ||
	E == f32,
	N == 3 ||
	N == 4 {
	mu.push_id(ctx, uintptr(v)); defer mu.pop_id(ctx)

	sizes: [dynamic; 6]i32
	label_width: i32
	if label != "" {
		label_width = ctx.text_width(ctx.style.font, label) + ctx.style.padding * 2
		append(&sizes, label_width)
	}

	color_rect_size := ctx.style.size.y + ctx.style.padding * 2
	cells := i32(N)
	if label != "" do cells += 1
	avail :=
		mu.get_current_container(ctx).body.w -
		ctx.style.padding * 2 -
		ctx.style.spacing * cells -
		label_width -
		color_rect_size
	sw := avail / N
	for _ in 0 ..< N {
		append(&sizes, sw)
	}
	append(&sizes, color_rect_size)

	mu.layout_row(ctx, sizes[:])
	if label != "" do mu.label(ctx, label)
	for i in 0 ..< N {
		res |= mu_numeric_raw(ctx, "", &v[i], low, high, step, kind)
	}
	color: mu.Color

	S :: 255 when E == f32 else 1
	c := ln.array_cast(v^ * S, u8)

	when N == 3 {
		color = {c.r, c.g, c.b, 255}
	} else when N == 4 {
		color = {c.r, c.g, c.b, c.a}
	}

	mu.draw_rect(ctx, mu.layout_next(ctx), color)

	return
}

mu_combo :: proc(
	ctx: ^mu.Context,
	label: string,
	val: ^$T,
) -> (
	res: mu.Result_Set,
) where intrinsics.type_is_enum(T) {
	mu.push_id(ctx, uintptr(val)); defer mu.pop_id(ctx)

	if label != "" {
		label_width := ctx.text_width(ctx.style.font, label) + ctx.style.padding * 2
		mu.layout_row(ctx, {label_width, -1})
		mu.label(ctx, label)
	} else {
		mu.layout_row(ctx, {-1})
	}

	if .SUBMIT in mu.button(ctx, reflect.enum_string(val^)) {
		mu.open_popup(ctx, "popup")
	}

	r := ctx.last_rect
	cnt := mu.get_container(ctx, "popup", {.CLOSED})
	if cnt != nil && cnt.open && cnt.rect.w == 1 && cnt.rect.h == 1 {
		cnt.rect.x = r.x
		cnt.rect.y = r.y + r.h
	}

	if mu.begin_popup(ctx, "popup") {
		defer mu.end_popup(ctx)
		mu.layout_row(ctx, {r.w - ctx.style.padding * 2})

		for name, i in reflect.enum_field_names(T) {
			mu.push_id(ctx, name); defer mu.pop_id(ctx)
			if .SUBMIT in mu.button(ctx, name) {
				val^ = T(i)
				res = {.CHANGE}
				mu.get_current_container(ctx).open = false
			}
		}
	}

	return
}
