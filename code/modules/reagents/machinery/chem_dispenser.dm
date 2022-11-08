
//How many cell charge do we use per unit of chemical?
#define chemical_dispenser_ENERGY_COST (CHEM_SYNTH_ENERGY * CELLRATE)

//list of available bottle sprites, holding 60u bottles that hold just about any chem
#define BOTTLE_SPRITES list("bottle", "potion", "tincture")

//Pill bottles themselfs
#define PILL_BOTTLE_MODELS list("pill_canister", "pill_lred", "pill_dred", \
"pill_red", "pill_pink", "pill_orange", "pill_yellow", "pill_green", "pill_blue", \
"pill_white", "pill_black", "pill_rainbow")

//Syretties, the samll 5u refillable injectors
#define SYRETTE_SPRITES list("syrette", "syrette_red", "syrette_orange", \
"syrette_yellow", "syrette_green", "syrette_cyan", "syrette_blue", "syrette_magenta", \
"syrette_spacealine", "syrette_hyperzine", "syrette_fun", "syrette_fun1", "syrette_antitox", \
"syrette_inopravoline", "syrette_dexalinplus", "syrette_tricord", "syrette_quickclot") //list of available syrette sprites

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//To do, make matter bins, do something

/obj/machinery/chemical_dispenser
	name = "chem dispenser"
	icon = 'icons/obj/chemical.dmi'
	icon_state = "dispenser"
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE // Handles power use in Process()
	layer = BELOW_OBJ_LAYER
	circuit = /obj/item/circuitboard/chemical_dispenser
	var/fancy_hack = FALSE
	var/ui_title = "Chem Dispenser 5000"
	var/obj/item/cell/medium/cell
	var/amount = 30
	var/cell_charger_additon = 0 //This is not a TRUE/FALSE
	var/accept_beaker = TRUE //At TRUE, ONLY accepts beakers.
	var/hackedcheck = FALSE
	var/list/dispensable_reagents //I seriously hope this fixes the scrambling on part upgrade.
	var/list/level0 = list(
		"acetone", "aluminum", "ammonia",
		"carbon", "copper", "ethanol",
		"hclacid", "hydrazine", "iron",
		"lithium", "mercury", "phosphorus",
		"potassium", "radium", "sacid",
		"silicon", "sodium", "sugar",
		"sulfur", "tungsten", "water",
	)

	var/list/level1 = list("oil", "cryptobiolin")
	var/list/level2 = list("toxin", "sodiumchloride")
	var/list/level3 = list("mutagen")
	var/list/level4 = list("inaprovaline")

	var/list/hacked_reagents = list("mindbreaker", "cleaner") //USEFUL stuff
	var/obj/item/reagent_containers/beaker = null

/obj/machinery/chemical_dispenser/RefreshParts()
	cell = locate() in component_parts

	var/man_rating = 0
	var/man_amount = 0
	for(var/obj/item/stock_parts/manipulator/M in component_parts)
		man_rating += M.rating
		man_amount++
	man_rating -= man_amount

	dispensable_reagents = level0.Copy()

	if(man_rating >= 2)
		dispensable_reagents += level1
	if(man_rating >= 3)
		dispensable_reagents += level2
	if(man_rating >= 4)
		dispensable_reagents += level3
	if(man_rating >= 5)
		dispensable_reagents += level4

	var/capa_rating = 0
	var/capa_amount = 0
	for(var/obj/item/stock_parts/capacitor/C in component_parts)
		capa_rating += C.rating
		capa_amount++
	capa_rating -= capa_amount

	cell_charger_additon = capa_rating // theirs only 1 in dispenders min 34 max 120 RnD 60 Greyson 100

/obj/machinery/chemical_dispenser/proc/recharge()
	if(stat & (BROKEN|NOPOWER)) return
	//Calculates the charge rate. 800 battery starts at 48 which is high. So we pull that back a bit.
	var/addenergy = cell.give(clamp((cell.maxcharge*cell.max_chargerate) / 2 + (cell_charger_additon*20 / 2),0,cell.maxcharge))
	if(addenergy)
		use_power(addenergy / CELLRATE)
		SSnano.update_uis(src) // update all UIs attached to src

/obj/machinery/chemical_dispenser/Process()
	if(cell && cell.percent() < 100)
		recharge()

/obj/machinery/chemical_dispenser/power_change()
	..()
	update_icon()
	SSnano.update_uis(src) // update all UIs attached to src

/obj/machinery/chemical_dispenser/proc/hacked(mob/user)
	//..()
	if(!hackedcheck)
		to_chat(user, "You change the mode from 'Safe' to 'Unsafe'.")
		dispensable_reagents += hacked_reagents
		SSnano.update_uis(src)
		hackedcheck = TRUE
		return

	else
		to_chat(user, "You change the mode from 'Unsafe' to 'Safe'.")
		dispensable_reagents -= hacked_reagents
		SSnano.update_uis(src)
		hackedcheck = FALSE
		return



/obj/machinery/chemical_dispenser/Initialize()
	. = ..()
	dispensable_reagents = sortList(dispensable_reagents)
	if(fancy_hack) // Does the machine start already hacked?
		hackedcheck = !hackedcheck // Not sure what this var do, but better safe than sorry
		dispensable_reagents += hacked_reagents // Add the hacked chems
		SSnano.update_uis(src) // Update the ui to be safe.

/obj/machinery/chemical_dispenser/ex_act(severity)
	switch(severity)
		if(1)
			qdel(src)
			return
		if(2)
			if(prob(50))
				qdel(src)
				return

/obj/machinery/chemical_dispenser/nano_ui_data()
	var/list/data = list()
	data["amount"] = amount
	data["energy"] = round(cell.charge)
	data["maxEnergy"] = round(cell.maxcharge)
	data["accept_beaker"] = accept_beaker

	var/list/chemicals = list()
	for (var/re in dispensable_reagents)
		var/datum/reagent/temp = GLOB.chemical_reagents_list[re]
		if(temp)
			chemicals.Add(list(list("title" = temp.name, "id" = temp.id, "commands" = list("dispense" = temp.id)))) // list in a list because Byond merges the first list...
	data["chemicals"] = chemicals

	if(beaker)
		data["beaker"] = beaker.reagents.nano_ui_data()

	return data

/obj/machinery/chemical_dispenser/nano_ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = NANOUI_FOCUS)
	var/list/data = nano_ui_data()

	// update the ui if it exists, returns null if no ui is passed/found
	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		// the ui does not exist, so we'll create a new() one
        // for a list of parameters and their descriptions see the code docs in \code\modules\nano\nanoui.dm
		ui = new(user, src, ui_key, "chem_dispenser.tmpl", ui_title, 390, 655)
		// when the ui is first opened this is the data it will use
		ui.set_initial_data(data)
		// open the new ui window
		ui.open()

/obj/machinery/chemical_dispenser/proc/detach()
	if(beaker)
		var/obj/item/reagent_containers/B = beaker
		B.loc = loc
		beaker = null
		update_icon()

/obj/machinery/chemical_dispenser/AltClick(mob/living/user)
	if(user.incapacitated())
		to_chat(user, SPAN_WARNING("You can't do that right now!"))
		return
	if(!in_range(src, user))
		return
	src.detach()

/obj/machinery/chemical_dispenser/Topic(href, href_list)
	if(..())
		return

	if(href_list["amount"])
		// Since the user can actually type the commands himself, some sanity checking
		amount = round(text2num(href_list["amount"]), 5) // round to nearest 5
		amount = CLAMP(amount, 0, 120)

	if(href_list["dispense"])
		if (dispensable_reagents.Find(href_list["dispense"]) && beaker && beaker.is_refillable())
			var/obj/item/reagent_containers/B = src.beaker
			var/datum/reagents/R = B.reagents
			var/space = R.maximum_volume - R.total_volume

			var/added_amount = min(amount, cell.charge / chemical_dispenser_ENERGY_COST, space)
			R.add_reagent(href_list["dispense"], added_amount)
			cell.use(added_amount * chemical_dispenser_ENERGY_COST)
			investigate_log("dispensed [href_list["dispense"]] into [B], while being operated by [key_name(usr)]", "chemistry")

	if(href_list["ejectBeaker"])
		src.detach()

	return 1 // update UIs attached to this object


/obj/machinery/chemical_dispenser/MouseDrop_T(atom/movable/I, mob/user, src_location, over_location, src_control, over_control, params)
	if(!Adjacent(user) || !I.Adjacent(user) || user.stat)
		return ..()
	if(istype(I, /obj/item/reagent_containers) && I.is_open_container() && !beaker)
		if(user.drop_from_inventory(I))
			user.drop_from_inventory(I)
			I.forceMove(src)
			I.add_fingerprint(user)
			beaker = I
			to_chat(user, SPAN_NOTICE("You add [I] to [src]."))
			SSnano.update_uis(src) // update all UIs attached to src
			return
	. = ..()

/obj/machinery/chemical_dispenser/attackby(obj/item/I, mob/living/user)
	if(default_deconstruction(I, user))
		return

	if(default_part_replacement(I, user))
		return

	if(!user.stats?.getPerk(PERK_NERD) && !user.stats?.getPerk(PERK_MEDICAL_EXPERT) && !usr.stat_check(STAT_BIO, STAT_LEVEL_BASIC) && !simple_machinery && !usr.stat_check(STAT_COG, 30)) //Are we missing the perk AND to low on bio? Needs 15 bio so 30 to bypass
		to_chat(usr, SPAN_WARNING("Your biological understanding isn't enough to use this."))
		return

	if(istype(I, /obj/item/tool/multitool) && length(hacked_reagents))
		hacked()

	var/obj/item/reagent_containers/B = I
	if(beaker)
		to_chat(user, "Something is already loaded into the machine.")
		return
	if(istype(B, /obj/item/reagent_containers/glass) || istype(B, /obj/item/reagent_containers/food))
		if(accept_beaker && istype(B, /obj/item/reagent_containers/food))
			to_chat(user, SPAN_NOTICE("This machine only accepts beakers"))
		src.beaker =  B
		if (user.unEquip(B, src))
			to_chat(user, "You set [B] on the machine.")
			update_icon()
			SSnano.update_uis(src) // update all UIs attached to src
			return

/obj/machinery/chemical_dispenser/attack_hand(mob/living/user)
	if(stat & BROKEN)
		return
	if(!user.stats?.getPerk(PERK_NERD) && !user.stats?.getPerk(PERK_MEDICAL_EXPERT) && !usr.stat_check(STAT_BIO, STAT_LEVEL_BASIC) && !simple_machinery && !usr.stat_check(STAT_COG, 30)) //Are we missing the perk AND to low on bio? Needs 15 bio so 30 to bypass
		to_chat(usr, SPAN_WARNING("Your biological understanding isn't enough to use this."))
		return
	nano_ui_interact(user)

/obj/machinery/chemical_dispenser/soda
	icon_state = "soda_dispenser"
	name = "soda fountain"
	desc = "A drink fabricating machine, capable of producing many sugary drinks with just one touch."
	layer = OBJ_LAYER
	ui_title = "Soda Dispens-o-matic"
	var/icon_on = "soda_dispenser"
	fancy_hack = FALSE
	accept_beaker = FALSE
	density = FALSE
	simple_machinery = TRUE
	level0 = list(
		"water","ice","icetea","icegreentea","cola","spacemountainwind","dr_gibb","space_up",
		"tonic","sodawater","lemon_lime","sugar","orangejuice","limejuice","lemonjuice", "pineapplejuice", "berryjuice","grapesoda","watermelonjuice")

	level1 = list("capsaicin", "carbon")
	level2 = list("banana")
	level3 = list("soymilk") //Commie stock part gives this
	level4 = list("enzyme")

	hacked_reagents = list("thirteenloko")
	circuit = /obj/item/circuitboard/chemical_dispenser/soda

/obj/machinery/chemical_dispenser/soda/hacked(mob/user)
	if(!hackedcheck)
		to_chat(user, "You change the mode from 'McNano' to 'Pizza King'.")
		dispensable_reagents += hacked_reagents
		SSnano.update_uis(src)
		hackedcheck = TRUE
		return
	else
		to_chat(user, "You change the mode from 'Pizza King' to 'McNano'.")
		dispensable_reagents -= hacked_reagents
		SSnano.update_uis(src)
		hackedcheck = FALSE
		return

/obj/machinery/chemical_dispenser/soda/update_icon()
	cut_overlays()
	if(stat & (BROKEN|NOPOWER))
		icon_state = icon_on+"_off"
	else
		icon_state = icon_on

	if(beaker)
		add_overlay(image(icon, icon_on+"_loaded"))

/obj/machinery/chemical_dispenser/coffee_master
	icon_state = "coffee_master"
	name = "coffee master"
	desc = "The only thing that can get some workers though the day."
	layer = OBJ_LAYER
	ui_title = "Coffee Master 3000"
	fancy_hack = FALSE
	accept_beaker = FALSE
	density = FALSE
	simple_machinery = TRUE
	level0 = list(
		"coffee","cream","tea","greentea","sugar","hot_coco","espresso","milk")
	hacked_reagents = list("ice")
	level1 = list("cappuccino","coco")
	level2 = list("macchiato")
	level3 = list("soymilk") //Commie stock part gives this
	level4 = list("kahlua")
	circuit = /obj/item/circuitboard/chemical_dispenser/coffee_master

/obj/machinery/chemical_dispenser/beer
	icon_state = "booze_dispenser"
	name = "booze dispenser"
	layer = OBJ_LAYER
	ui_title = "Booze Portal 9001"
	fancy_hack = FALSE
	accept_beaker = FALSE
	density = FALSE
	simple_machinery = TRUE
	desc = "A technological marvel, supposedly able to mix just the mixture you'd like to drink the moment you ask for one."
	level0 = list(
		"lemon_lime","sugar","orangejuice","limejuice",
		"sodawater","tonic","beer","kahlua","whiskey",
		"wine","vodka","gin","rum","tequilla","vermouth",
		"cognac","ale","mead", "fernet")

	level1 = list("melonliquor", "bluecuracao", "ethanol")
	level2 = list("sake", "irishcream")
	level3 = list("alliescocktail") //Commie stock part gives this
	level4 = list("enzyme")

	hacked_reagents = list("goldschlager","patron","berryjuice")
	circuit = /obj/item/circuitboard/chemical_dispenser/beer

/obj/machinery/chemical_dispenser/beer/hacked(mob/user)
	if(!hackedcheck)
		to_chat(user, "You disable the 'cheap bastards' lock, enabling hidden and very expensive boozes.")
		dispensable_reagents += hacked_reagents
		SSnano.update_uis(src)
		hackedcheck = TRUE
		return
	else
		to_chat(user, "You re-enable the 'cheap bastards' lock, disabling hidden and very expensive boozes.")
		dispensable_reagents -= hacked_reagents
		SSnano.update_uis(src)
		hackedcheck = FALSE
		return

/obj/machinery/chemical_dispenser/meds_admin_debug
	name = "mysterious chemical dispenser"
	desc = "A mysterious chemical dispenser that can produce all sorts of highly advanced medicines at the press of a button."
	ui_title = "Cheat Synthesizer 1337"
//Admin dispender gets nuffen
	level1 = list(null)
	level2 = list(null)
	level3 = list(null)
	level4 = list(null)

	level0 = list(
		"inaprovaline","ryetalyn","paracetamol",
		"tramadol","oxycodone","sterilizine",
		"leporazine","kelotane","dermaline",
		"dexalin","dexalinp","tricordrazine",
		"anti_toxin","synaptizine","hyronalin",
		"arithrazine","alkysine","imidazoline",
		"peridaxon","bicaridine","meralyne","hyperzine",
		"rezadone","spaceacillin","ethylredoxrazine",
		"stoxin","chloralhydrate","cryoxadone",
		"clonexadone","ossisine","noexcutite","kyphotorin",
		"detox","polystem","purger","addictol","aminazine",
		"vomitol","haloperidol","paroxetine","citalopram",
		"methylphenidate"
	)

/obj/machinery/chemical_dispenser/industrial
	name = "industrial chem dispenser"
	icon = 'icons/obj/machines/chemistry.dmi'
	icon_state = "industrial_dispenser"
	ui_title = "Industrial Dispenser 4835"
	circuit = /obj/item/circuitboard/chemical_dispenser/industrial
	level0 = list(
		"acetone","aluminum","ammonia",
		"copper","ethanol","hclacid",
		"hydrazine","iron","phosphorus",
		"potassium", "radium","sacid",
		"silicon","sulfur","tungsten"
	)

	level1 = list("oil", "cryptobiolin", "sterilizine")
	level2 = list("foaming_agent", "plasticide", "instant_ice")
	level3 = list("pacid") //Now it has chems for what it's supposed to do, and worth upgrading past Picos

	hacked_reagents = list("cleaner","surfactant","silicate","coolant") //So we have a reason to keep you
