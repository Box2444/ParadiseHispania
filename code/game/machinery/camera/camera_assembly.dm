/obj/item/camera_assembly
	name = "camera assembly"
	desc = "A pre-fabricated security camera kit, ready to be assembled and mounted to a surface."
	icon = 'icons/obj/monitors.dmi'
	icon_state = "cameracase"
	w_class = WEIGHT_CLASS_SMALL
	anchored = 0
	materials = list(MAT_METAL=400, MAT_GLASS=250)

	//	Motion, EMP-Proof, X-Ray
	var/list/obj/item/possible_upgrades = list(/obj/item/assembly/prox_sensor, /obj/item/stack/sheet/mineral/plasma, /obj/item/analyzer)
	var/list/upgrades = list()
	var/state = 0
	var/busy = 0
	/*
				0 = Nothing done to it
				1 = Wrenched in place
				2 = Welded in place
				3 = Wires attached to it (you can now attach/dettach upgrades)
				4 = Screwdriver panel closed and is fully built (you cannot attach upgrades)
	*/

/obj/item/camera_assembly/Destroy()
	QDEL_LIST(upgrades)
	return ..()

/obj/item/camera_assembly/attackby(obj/item/W, mob/living/user, params)

	switch(state)
		if(0)
			// State 0
			if(iswrench(W) && isturf(src.loc))
				playsound(src.loc, W.usesound, 50, 1)
				to_chat(user, "You wrench the assembly into place.")
				anchored = 1
				state = 1
				update_icon()
				auto_turn()
				return

		if(1)
			// State 1
			if(iswelder(W))
				if(weld(W, user))
					to_chat(user, "You weld the assembly securely into place.")
					anchored = 1
					state = 2
				return

			else if(iswrench(W))
				playsound(src.loc, W.usesound, 50, 1)
				to_chat(user, "You unattach the assembly from it's place.")
				anchored = 0
				update_icon()
				state = 0
				return

		if(2)
			// State 2
			if(iscoil(W))
				var/obj/item/stack/cable_coil/C = W
				if(C.use(2))
					to_chat(user, "<span class='notice'>You add wires to the assembly.</span>")
					playsound(loc, W.usesound, 50, 1)
					state = 3
				else
					to_chat(user, "<span class='warning'>You need 2 coils of wire to wire the assembly.</span>")
				return

			else if(iswelder(W))

				if(weld(W, user))
					to_chat(user, "You unweld the assembly from it's place.")
					state = 1
					anchored = 1
				return


		if(3)
			// State 3
			if(isscrewdriver(W))
				playsound(src.loc, W.usesound, 50, 1)

				var/input = strip_html(input(usr, "Which networks would you like to connect this camera to? Seperate networks with a comma. No Spaces!\nFor example: SS13,Security,Secret ", "Set Network", "SS13"))
				if(!input)
					to_chat(usr, "No input found please hang up and try your call again.")
					return

				var/list/tempnetwork = splittext(input, ",")
				if(tempnetwork.len < 1)
					to_chat(usr, "No network found please hang up and try your call again.")
					return

				var/area/camera_area = get_area(src)
				var/temptag = "[sanitize(camera_area.name)] ([rand(1, 999)])"
				input = strip_html(input(usr, "How would you like to name the camera?", "Set Camera Name", temptag))

				state = 4
				var/obj/machinery/camera/C = new(src.loc)
				src.loc = C
				C.assembly = src

				C.auto_turn()

				C.network = uniquelist(tempnetwork)
				tempnetwork = difflist(C.network,restricted_camera_networks)
				if(!tempnetwork.len)//Camera isn't on any open network - remove its chunk from AI visibility.
					cameranet.removeCamera(C)

				C.c_tag = input

				for(var/i = 5; i >= 0; i -= 1)
					var/direct = input(user, "Direction?", "Assembling Camera", null) in list("LEAVE IT", "NORTH", "EAST", "SOUTH", "WEST" )
					if(direct != "LEAVE IT")
						C.dir = text2dir(direct)
					if(i != 0)
						var/confirm = alert(user, "Is this what you want? Chances Remaining: [i]", "Confirmation", "Yes", "No")
						if(confirm == "Yes")
							break
				return

			else if(iswirecutter(W))
				new/obj/item/stack/cable_coil(get_turf(src), 2)
				playsound(src.loc, W.usesound, 50, 1)
				to_chat(user, "You cut the wires from the circuits.")
				state = 2
				return

	// Upgrades!
	if(is_type_in_list(W, possible_upgrades) && !is_type_in_list(W, upgrades)) // Is a possible upgrade and isn't in the camera already.
		if(!user.unEquip(W))
			to_chat(user, "<span class='warning'>[W] is stuck!</span>")
			return
		to_chat(user, "You attach \the [W] into the assembly inner circuits.")
		upgrades += W
		user.drop_item()
		W.loc = src
		return

	// Taking out upgrades
	else if(iscrowbar(W) && upgrades.len)
		var/obj/U = locate(/obj) in upgrades
		if(U)
			to_chat(user, "You unattach an upgrade from the assembly.")
			playsound(src.loc, W.usesound, 50, 1)
			U.loc = get_turf(src)
			upgrades -= U
		return

	..()

/obj/item/camera_assembly/update_icon()
	if(anchored)
		icon_state = "camera1"
	else
		icon_state = "cameracase"

/obj/item/camera_assembly/attack_hand(mob/user as mob)
	if(!anchored)
		..()

/obj/item/camera_assembly/proc/weld(var/obj/item/weldingtool/WT, var/mob/living/user)

	if(busy)
		return 0
	if(!WT.remove_fuel(0, user))
		return 0

	to_chat(user, "<span class='notice'>You start to weld the [src]..</span>")
	playsound(src.loc, WT.usesound, 50, 1)
	busy = 1
	if(do_after(user, 20 * WT.toolspeed, target = src))
		busy = 0
		if(!WT.isOn())
			return 0
		return 1
	busy = 0
	return 0
