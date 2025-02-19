/obj/machinery/r_n_d/protolathe
	name = "protolathe"
	desc = "An upgraded variant of a common Autolathe, this can only be operated via a nearby RnD console, but can manufacture cutting edge technology, provided it has the design and the correct materials."
	icon_state = "protolathe"
	atom_flags = ATOM_FLAG_OPEN_CONTAINER

	idle_power_usage = 30
	active_power_usage = 5000

	var/max_material_storage = 100000
	var/list/materials = list(DEFAULT_WALL_MATERIAL = 0, MATERIAL_GLASS = 0, MATERIAL_GOLD = 0, MATERIAL_SILVER = 0, MATERIAL_PHORON = 0, MATERIAL_URANIUM = 0, MATERIAL_DIAMOND = 0)

	var/list/datum/design/queue = list()
	var/progress = 0

	var/mat_efficiency = 1
	var/speed = 1

	component_types = list(
		/obj/item/circuitboard/protolathe,
		/obj/item/stock_parts/matter_bin = 2,
		/obj/item/stock_parts/manipulator = 2,
		/obj/item/reagent_containers/glass/beaker = 2
	)

/obj/machinery/r_n_d/protolathe/process()
	..()
	if(stat)
		update_icon()
		return
	if(queue.len == 0)
		busy = 0
		update_icon()
		return
	var/datum/design/D = queue[1]
	if(canBuild(D))
		busy = 1
		progress += speed
		if(progress >= D.time)
			build(D)
			progress = 0
			removeFromQueue(1)
			if(linked_console)
				linked_console.updateUsrDialog()
		update_icon()
	else
		if(busy)
			visible_message("<span class='notice'>[icon2html(src, viewers(get_turf(src)))] [src] flashes: insufficient materials: [getLackingMaterials(D)].</span>")
			busy = 0
			update_icon()

/obj/machinery/r_n_d/protolathe/proc/TotalMaterials() //returns the total of all the stored materials. Makes code neater.
	var/t = 0
	for(var/f in materials)
		t += materials[f]
	return t

/obj/machinery/r_n_d/protolathe/RefreshParts()
	// Adjust reagent container volume to match combined volume of the inserted beakers
	var/T = 0
	for(var/obj/item/reagent_containers/glass/G in component_parts)
		T += G.reagents.maximum_volume
	create_reagents(T)
	// Transfer all reagents from the beakers to internal reagent container
	for(var/obj/item/reagent_containers/glass/G in component_parts)
		G.reagents.trans_to_obj(src, G.reagents.total_volume)

	// Adjust material storage capacity to scale with matter bin rating
	max_material_storage = 0
	for(var/obj/item/stock_parts/matter_bin/M in component_parts)
		max_material_storage += M.rating * 75000

	// Adjust production speed to increase with manipulator rating
	T = 0
	for(var/obj/item/stock_parts/manipulator/M in component_parts)
		T += M.rating
	mat_efficiency = 1 - (T - 2) / 8
	speed = T / 2

/obj/machinery/r_n_d/protolathe/dismantle()
	for(var/obj/I in component_parts)
		if(istype(I, /obj/item/reagent_containers/glass/beaker))
			reagents.trans_to_obj(I, reagents.total_volume)
	for(var/f in materials)
		if(materials[f] >= SHEET_MATERIAL_AMOUNT)
			var/path = getMaterialType(f)
			if(path)
				var/obj/item/stack/S = new path(loc)
				S.amount = round(materials[f] / SHEET_MATERIAL_AMOUNT)
	..()

/obj/machinery/r_n_d/protolathe/update_icon()
	if(panel_open)
		icon_state = "protolathe_t"
	else if(busy)
		icon_state = "protolathe_n"
	else
		icon_state = "protolathe"

/obj/machinery/r_n_d/protolathe/attackby(obj/item/attacking_item, mob/user)
	if(busy)
		to_chat(user, "<span class='notice'>\The [src] is busy. Please wait for completion of previous operation.</span>")
		return 1
	if(default_deconstruction_screwdriver(user, attacking_item))
		if(linked_console)
			linked_console.linked_lathe = null
			linked_console = null
		return
	if(default_deconstruction_crowbar(user, attacking_item))
		return
	if(default_part_replacement(user, attacking_item))
		return
	if(attacking_item.is_open_container())
		return 1
	if(panel_open)
		to_chat(user, "<span class='notice'>You can't load \the [src] while it's opened.</span>")
		return 1
	if(!linked_console)
		to_chat(user, "<span class='notice'>\The [src] must be linked to an R&D console first!</span>")
		return 1
	if(!istype(attacking_item, /obj/item/stack/material))
		to_chat(user, "<span class='notice'>You cannot insert this item into \the [src]!</span>")
		return 1
	if(stat)
		return 1

	if(TotalMaterials() + SHEET_MATERIAL_AMOUNT > max_material_storage)
		to_chat(user, "<span class='notice'>\The [src]'s material bin is full. Please remove material before adding more.</span>")
		return 1

	var/obj/item/stack/material/stack = attacking_item
	if(!stack.default_type)
		to_chat(user, SPAN_WARNING("This stack cannot be used!"))
		return
	var/amount = round(input("How many sheets do you want to add?") as num)//No decimals
	if(!attacking_item)
		return
	if(!Adjacent(user))
		to_chat(user, "<span class='notice'>\The [src] is too far away for you to insert this.</span>")
		return
	if(amount <= 0)//No negative numbers
		return
	if(amount > stack.get_amount())
		amount = stack.get_amount()
		if(max_material_storage - TotalMaterials() < (amount * SHEET_MATERIAL_AMOUNT)) //Can't overfill
			amount = min(stack.get_amount(), round((max_material_storage - TotalMaterials()) / SHEET_MATERIAL_AMOUNT))

	AddOverlays("protolathe_[stack.default_type]")
	CUT_OVERLAY_IN("protolathe_[stack.default_type]", 10)

	busy = 1
	use_power_oneoff(max(1000, (SHEET_MATERIAL_AMOUNT * amount / 10)))
	if(do_after(user, 16))
		if(stack.use(amount))
			to_chat(user, "<span class='notice'>You add [amount] sheets to \the [src].</span>")
			materials[stack.default_type] += amount * SHEET_MATERIAL_AMOUNT
	busy = 0
	updateUsrDialog()
	return

/obj/machinery/r_n_d/protolathe/proc/addToQueue(var/datum/design/D)
	queue += D

/obj/machinery/r_n_d/protolathe/proc/removeFromQueue(var/index)
	queue.Cut(index, index + 1)

/obj/machinery/r_n_d/protolathe/proc/canBuild(var/datum/design/D)
	for(var/M in D.materials)
		if(materials[M] < D.materials[M])
			return 0
	for(var/C in D.chemicals)
		if(!reagents.has_reagent(C, D.chemicals[C]))
			return 0
	return 1

/obj/machinery/r_n_d/protolathe/proc/getLackingMaterials(var/datum/design/D)
	var/ret = ""
	for(var/M in D.materials)
		if(materials[M] < D.materials[M])
			if(ret != "")
				ret += ", "
			ret += "[D.materials[M] - materials[M]] [M]"
	for(var/C in D.chemicals)
		if(!reagents.has_reagent(C, D.chemicals[C]))
			var/singleton/reagent/R = GET_SINGLETON(C)
			if(ret != "")
				ret += ", "
			ret += "[R.name]"
	return ret

/obj/machinery/r_n_d/protolathe/proc/build(var/datum/design/D)
	var/power = active_power_usage
	for(var/M in D.materials)
		power += round(D.materials[M] / 5)
	power = max(active_power_usage, power)
	use_power_oneoff(power)
	for(var/M in D.materials)
		materials[M] = max(0, materials[M] - D.materials[M] * mat_efficiency)
	for(var/C in D.chemicals)
		reagents.remove_reagent(C, D.chemicals[C] * mat_efficiency)

	intent_message(MACHINE_SOUND)

	if(D.build_path)
		var/obj/new_item = D.Fabricate(src, src)
		new_item.forceMove(loc)
		if(mat_efficiency != 1) // No matter out of nowhere
			if(new_item.matter && new_item.matter.len > 0)
				for(var/i in new_item.matter)
					new_item.matter[i] = new_item.matter[i] * mat_efficiency
