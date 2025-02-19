/obj/item/clothing/gloves/attackby(obj/item/attacking_item, mob/user)
	if(attacking_item.ismultitool())
		var/siemens_percentage = 100 * siemens_coefficient
		to_chat(user, SPAN_NOTICE("You probe \the [src] with \the [attacking_item]. The gloves will let [siemens_percentage]% of an electric shock through."))
		return

	if(is_sharp(attacking_item))
		if(clipped)
			to_chat(user, SPAN_NOTICE("\The [src] have already been clipped!"))
			update_icon()
			return

		playsound(src.loc, 'sound/items/Wirecutter.ogg', 100, 1)
		user.visible_message(SPAN_WARNING("[user] cuts the fingertips off of \the [src]."),SPAN_WARNING("You cut the fingertips off of \the [src]."))

		clipped = 1
		siemens_coefficient += 0.25
		name = "modified [name]"
		desc = "[desc]<br>They have had the fingertips cut off of them."
		if("exclude" in species_restricted)
			species_restricted -= BODYTYPE_UNATHI
			species_restricted -= BODYTYPE_TAJARA
			species_restricted -= BODYTYPE_VAURCA
		return

	if(istype(src, /obj/item/clothing/gloves/boxing))			//quick fix for stunglove overlay not working nicely with boxing gloves.
		to_chat(user, "<span class='notice'>That won't work.</span>")	//i'm not putting my lips on that!)
		..()
		return
	else if(istype(src, /obj/item/clothing/gloves/force))
		to_chat(user, "<span class='notice'>That seems like a terrible idea.</span>")
		..()
		return

	//add wires
	if(attacking_item.iscoil())
		var/obj/item/stack/cable_coil/C = attacking_item
		if (clipped)
			to_chat(user, "<span class='notice'>The [src] are too badly mangled for wiring.</span>")
			return

		if(wired)
			to_chat(user, "<span class='notice'>The [src] are already wired.</span>")
			return

		if(C.amount < 2)
			to_chat(user, "<span class='notice'>There is not enough wire to cover the [src].</span>")
			return

		C.use(2)
		wired = 1
		siemens_coefficient = 3.0
		to_chat(user, "<span class='notice'>You wrap some wires around the [src].</span>")
		update_icon()
		return

	//add cell
	else if(wired && istype(attacking_item, /obj/item/cell))
		if(cell)
			to_chat(user, "<span class='notice'>\A [cell] is already attached to the [src].</span>")
			return
		user.drop_from_inventory(attacking_item, src)
		cell = attacking_item
		w_class = ITEMSIZE_NORMAL
		to_chat(user, "<span class='notice'>You attach \the [cell] to the [src].</span>")
		update_icon()
		return

	else if((cell || wired) && (attacking_item.iswirecutter() || istype(attacking_item, /obj/item/surgery/scalpel)))

		//stunglove stuff
		if(cell)
			cell.update_icon()
			to_chat(user, "<span class='notice'>You cut \the [cell] away from the [src].</span>")
			cell.forceMove(get_turf(src.loc))
			cell = null
			w_class = ITEMSIZE_SMALL
			update_icon()
			return
		if(wired) //wires disappear into the void because fuck that shit
			wired = 0
			siemens_coefficient = initial(siemens_coefficient)
			to_chat(user, "<span class='notice'>You cut the wires away from the [src].</span>")
			update_icon()
			return

	return ..()
