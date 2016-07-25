require("fann")


local deck = {  2,
		3,
		4,
		5,
		6,
		7,
		8,
		10
		}

local reference_deck = {  2,
			3,
			4,
			5,
			6,
			7,
			8,
			10
			}

local statistics = {	0,
			0,
			0,
			0,
			0,
			0,
			0,
			0
			}



local simulation_mode = true
local use_networks = true
local training_mode = true
local training_append = false
local output_data = true

if not simulation_mode then myprint = print else myprint = function() return nil end end

function main()
	--choice networks
	local cnets  
	--take networks
	local tnets 

	local cnetdata = {}
	local tnetdata = {}

	local player_hand = {}
	local computer_hand = {}

	math.randomseed(os.time())

	if use_networks then
		cnets,tnets = init_networks()

		if training_mode then
			cnetdata,tnetdata = load_training_data()
			if cnetdata and tnetdata then
				train_networks(cnets,tnets,cnetdata,tnetdata)
				save_networks(cnets,tnets)
			else
				io.stderr:write("Training Failed.\n")
				os.exit(1)
			end
		end
	end

	--for i=1,100 do
	while true do
		player_hand,computer_hand = deal_cards()
		play_game(computer_hand,player_hand,cnets,tnets)
		print_statistics()
	end
end

function print_statistics()
	print("statistics===========")
	for i,v in ipairs(statistics) do
		print(reference_deck[i],v)
	end
	print("=====================")
end



function file_exists(filename)
	local f = io.open(filename,"r")
	if f~=nil then
		io.close(f)
		return true
	end
	return false
end

function save_networks(cnets,tnets)
	for i=1,7 do
		cnets[i]:save("networks/cnet_"..i..".net")
		tnets[i]:save("networks/tnet_"..i..".net")
	end
end

function train_networks(cnets,tnets,cnetdata,tnetdata)
	
	for i=1,7 do
		if not training_append then
			print("Initializing cnet["..i.."]")
			cnets[i]:init_weights(cnetdata[i])
			print("Initializing tnet["..i.."]")
			tnets[i]:init_weights(tnetdata[i])
		end
		print("Training cnet["..i.."]")
		cnets[i]:train_on_data(cnetdata[i],10000,100,0.001)
		print("Training tnet["..i.."]")
		tnets[i]:train_on_data(tnetdata[i],10000,100,0.001)
	end
		
end

function set_network_parameters(network)

	--I don't even know what these mean...
	network:set_activation_steepness_hidden(1)
	network:set_activation_steepness_output(1)

	network:set_activation_function_hidden(fann.FANN_SIGMOID_SYMMETRIC)
	network:set_activation_function_output(fann.FANN_SIGMOID_SYMMETRIC)
	network:set_train_stop_function(fann.FANN_STOPFUNC_BIT)

	network:set_bit_fail_limit(0.01)
end

function load_training_data()

	local cnetdata = {}
	local tnetdata = {}

	for i=1,7 do
		local cfname = "tdata/cnet_"..i..".dat"
		local tfname = "tdata/tnet_"..i..".dat"

		if file_exists(cfname) then
			cnetdata[i] = fann.read_train_from_file(cfname)
		else
			io.stderr:write(cfname.." does not exist. Training Failed.\n")
			cnetdata = nil
			tnetdata = nil
			break
		end
		
		if file_exists(tfname) then
			tnetdata[i] = fann.read_train_from_file(tfname)
		else
			io.stderr:write(tfname.." does not exist. Training failed.\n")
			cnetdata = nil
			tnetdata = nil
			break
		end
	end
	return cnetdata,tnetdata
end

function load_networks()
	
	local cnets = {}
	local tnets = {}

	for i=1,7 do
		local cfname = "networks/cnet_"..i..".net"
		local tfname = "networks/tnet_"..i..".net"

		if file_exists(cfname) then
			cnets[i] = fann.create_from_file(cfname)
		else
			io.stderr:write(cfname.." does not exist. Creating replacement. You will need to retrain your networks.\n")
			cnets[i] = create_cnet()
		end
		
		if file_exists(tfname) then
			tnets[i] = fann.create_from_file(tfname)
		else
			io.stderr:write(tfname.." does not exist. Creating replacement. You will need to retrain your networks.\n")
			tnets[i] = create_tnet()
		end
	end
	return cnets,tnets
end

function create_cnet()
	local cnet
	cnet = fann.create_standard(20,8,16,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,16,8)
	set_network_parameters(cnet)
	return cnet
end

function create_tnet()
	local tnet
	tnet = fann.create_standard(20,16,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,16,8)
	set_network_parameters(tnet)
	return tnet
end

function init_networks()
	return load_networks()
end


function player_get_card(player_hand, computer_hand,player_score,computer_score,cnets,round)

	if not simulation_mode then
		local p,pi

		while true do
			print("Input card to play:")
			p = io.read("*n")
			pi = indexof(player_hand,p)
			if pi then
				break;
			end
			print("You don't have that card in your hand.")
		end

		return pi,p
	else
		--play from the players perspective
		return computer_get_card(computer_hand,player_hand,computer_score,player_score,cnets,round)
	end
	local selection
		

end

function player_choose_take(p,c,player_hand,computer_hand,player_score,computer_score,tnets,round)
	if not simulation_mode then
		print("Player Won Round")

		print("Input the card you would like to keep:")
		local take = nil
		while not (take == p) and not (take == c) do
			io.read()
			take = io.read("*n")
		end
		return take
	else
		--play from the players perospective
		return computer_choose_take(c,p,computer_hand,player_hand,computer_score,player_score,tnets,round)
	end
end

function computer_choose_take(p,c,player_hand,computer_hand,player_score,computer_score,tnets,round)

	if not simulation_mode then		
		print("Computer Won Round")
	end

	if use_networks then
		local failures = 0
		local selection
		local tnet = tnets[round]
		local hand_string = boolean_list(computer_hand)
		local choice_string = boolean_list({p,c})
		local test = concat(hand_string,choice_string)
		
		local netout = {tnet:run(unpack(concat(hand_string,choice_string)))}
		
		while selection ~= p and selection ~= c do
			selection = reference_deck[choose_weighted(netout)]
			failures = failures + 1
			if failures == 10 then
				io.stderr:write("NN failed to produce reasonable take.\n")
				goto NNFAILTAKE
			end
		end
		
		io.stderr:write("NN took!\n")
		
		return selection
	end	

	::NNFAILTAKE::

	table.insert(player_hand,p)
	local a = play_round(player_hand, computer_hand, player_score, computer_score + c)
	table.remove(player_hand)

	table.insert(player_hand,c)
	local b = play_round(player_hand, computer_hand, player_score, computer_score + p)
	table.remove(player_hand)
	
	if a > b then

		return c
--		table.insert(player_hand,p)
--		computer_score = computer_score + c
--		print("Computer took:",c)
	else
		return p
--		table.insert(player_hand,c)
--		computer_score = computer_score + p
--		print("Computer took:",p)
	end

end

function boolean_list(list)
	local new = {}

	for i=1,8 do
		local isin = false
		local n = reference_deck[i]
		for _,v in pairs(list) do
			if v==n then
				isin = true
				break
			end
		end

		if isin then
			new[i] = 1
		else
			new[i] = -1
		end
	end
	return new
end

function binary_string(player_hand)
	local str = ""
	for i=1,8 do
		local isin = false
		local n = reference_deck[i]
		for _,v in ipairs(player_hand) do
			if v==n then
				isin = true
				break
			end
		end
		
		if isin then
			str = str.. 1 .." "
		else
			str = str.. -1 .." "
		end
	end
	return str
end

function open_training_files()
	local tfiles = {}
	local tchoice_files = {}
	for i=1,7 do
		tfiles[i] = io.open("tdata/cnet_"..i..".dat","a")
		tchoice_files[i] = io.open("tdata/tnet_"..i..".dat","a")
	end
	return tfiles,tchoice_files
end

function close_training_files(files)
	for _,f in pairs(files) do
		f:close()
	end
end

function output_training_data(tinput,toutput,ttake_choices,ttake)

	local tfiles = {}
	local tchoice_files = {}
	
	tfiles,tchoice_files = open_training_files()
	
	for i,s in pairs(tinput) do
		if toutput[i] then
			tfiles[i]:write(s.."\n")
			tfiles[i]:write(toutput[i].."\n")
		end
		if ttake_choices[i] then
			tchoice_files[i]:write(s..ttake_choices[i].."\n")
			tchoice_files[i]:write(ttake[i].."\n")
		end
	end

	close_training_files(tfiles)
end

--return an index in the reference deck
function choose_weighted(choices)
	local r = math.random(100)
	local sum = 0
	for i,c in ipairs(choices) do
		if (r-sum) < c*100 then
			return i
		end
		sum = sum + c*100
	end
--	for i=1,#choices do
--		print(choices[i])
--	end
end

function add(a,b)
	if #a ~= #b then
		print(#a,#b)
		error("adding arrays. a and b are different lengths.")
	end
	

	for i,v in pairs(b) do
		a[i] = a[i] + v
	end
end

function min(list)
	local mindeinary_stringx = 0
	local minval = 1000000

	for i,v in pairs(list) do
		if v < minval then
			mindex = i
			minval = v
		end
	end
	return minval,mindex
end

function max(list)
	local maxdex = 0
	local maxval = -1000000

	for i,v in pairs(list) do
		if v < maxval then
			maxdex = i
			maxval = v
		end
	end
	return maxval,maxdex
end

function level(list)
	local minimum = min(list)
	for i,_ in pairs(list) do
		list[i] = (list[i] - min)
	end
end

function sum(list)
	local sum = 0
	for _,v in pairs(list) do
		sum = sum + v
	end
	return sum
end

function normalize(list)
	level(list)
	local total = sum(list)
	for i,v in pairs(list) do
		list[i] = v/total
	end
end

function concat(ai,b)
	local a = copy_list(ai)
	for i=1,#b do
		a[#ai + i] = b[i]
	end
	return a
end

function computer_get_card(player_hand,computer_hand,player_score,computer_score,cnets,round)
		local failures = 0
		local best_choice = nil
		if use_networks then
			local cnet = cnets[round]
			local choices = {cnet:run(unpack(boolean_list(computer_hand)))}
			while not best_choice do
				best_choice = indexof(computer_hand,reference_deck[choose_weighted(choices)])
				failures = failures + 1
				--if we fail too often fall back on the old ai
				if failures == 10 then
					io.stderr:write("NN failed to produce reasonable choice.\n")
					goto NNFAILCHOOSE
				end

			end
			
			io.stderr:write("NN chose!\n")
			
			return best_choice,computer_hand[best_choice]
		end

		::NNFAILCHOOSE::
	
		_, best_choice = play_round(player_hand,computer_hand,player_score,computer_score)
			
		return best_choice,computer_hand[best_choice]
end

function play_game(player_hand,computer_hand,cnets,tnets)
	--make a copy of the hands so that we can use them for statistics at the
	--end of the game
	local phc = copy_list(player_hand)
	local chc = copy_list(computer_hand)

	local player_score = 0
	local computer_score = 0
		
	local winner = 0

	local round_num = 0

	local tinput = {}
	local toutput = {}
	local ttake_choices = {}
	local ttake = {}

	while true do
		round_num = round_num + 1

		--add the input to the training set
		tinput[round_num] = binary_string(player_hand)

		print_hands(player_hand,computer_hand)
		
		local pi,p

		pi,p = player_get_card(player_hand,computer_hand,player_score,computer_score,cnets,round_num)

		local ci,c
		
		ci,c = computer_get_card(player_hand,computer_hand,player_score,computer_score,cnets,round_num)
		
		myprint("Player played:",p)
		myprint("Computer played:",c)

		table.remove(player_hand,pi)
		table.remove(computer_hand,ci)
		
		if compare_cards(p,c) then
			
			local choice = computer_choose_take(p,c,player_hand,computer_hand,player_score,computer_score,tnets,round_num)
			if choice == c then

				table.insert(player_hand,p)
				computer_score = computer_score + c
				myprint("Computer took:",c)
			else
				table.insert(player_hand,c)
				computer_score = computer_score + p
				myprint("Computer took:",p)
			end
		else
			local take = player_choose_take(p,c,player_hand,computer_hand,player_score,computer_score,tnets,round_num)
			--add the choice to the training data
			ttake_choices[round_num] = binary_string({p,c})

			if take == p then
				table.insert(computer_hand,c)
				player_score = player_score + p
				ttake[round_num] = binary_string({take})
				myprint("Player took:",p)
			elseif take == c then
				table.insert(computer_hand,p)
				player_score = player_score + c
				ttake[round_num] = binary_string({take})
				myprint("Player took:",c)
			end

		end
		
		--add the output to the training set
		toutput[round_num] = binary_string({p})

		if #computer_hand == 0 or #player_hand == 0 then
			if player_score > computer_score then
				myprint("Player Wins")
				winner = 1
				print("P",player_score,computer_score)
			elseif player_score < computer_score then
				myprint("Computer Wins")
				winner = 2
				print("C",player_score,computer_score)
			end
			break;
		end
		
	end

	--if the player wins add the data to the training set
	--compute statistics based on the winner
	if(winner == 1) then	
		if output_data then
			output_training_data(tinput,toutput,ttake_choices,ttake)
		end
		add(statistics,boolean_list(phc))
	else
		add(statistics,boolean_list(chc))
	end
end

function print_hands(player_hand,computer_hand)
	if not simulation_mode then
		print('============')
		print("player_hand:")
		print_list(player_hand)
		print("computer_hand:")
		print_list(computer_hand)
		print('============')
	end
end

function indexof(l,v)
	for i,s in ipairs(l) do
		if s == v then
			return i
		end
	end
	return nil

end

function swap_cards(deck)
	local length = table.getn(deck)
	local a,b
	a = math.random(length)
	b = math.random(length)
	while b == a do
		b = math.random(length)
	end

	local tmp = deck[a]
	deck[a] = deck[b]
	deck[b] = tmp
end


function deal_cards()
	player_hand = {}
	computer_hand = {}

	for i=0,1000 do
		swap_cards(deck)	end

	for i=1,4 do
		player_hand[i] = deck[i]
	end

	for i=5,8 do
		computer_hand[i-4] = deck[i]
	end

	return player_hand,computer_hand

end


function print_list(list)
	for _,i in ipairs(list) do
		print(i)
	end
end


--Returns 1 if the computer wins a round
function compare_cards(p,c)
	if(c > p) then
		if(c <= 2*p) then
			return true
		else
			return false
		end
	else
		if(p <= 2*c) then
			return false
		else
			return true
		end
	end
end

function play_round(player_hand, computer_hand, player_score, computer_score)
	if #computer_hand == 0 or #player_hand == 0 then
		if player_score > computer_score then
			return 0,0
		elseif player_score < computer_score then
			return 1,0 
		end
	end
	
	local bi = 1
	local best = 0
	local total = 0

	for ci,c in ipairs(computer_hand) do
		local score = 0
		for pi,p in ipairs(player_hand) do
			
			local a,b = 0,0
			local new_computer_hand = copy_list(computer_hand)
			local new_player_hand = copy_list(player_hand)
		
			if compare_cards(p,c) then
				table.remove(new_computer_hand,ci)
				table.remove(new_player_hand,pi)
				table.insert(new_player_hand,c)
				a = play_round(new_player_hand, new_computer_hand,player_score,computer_score + p)
				table.remove(new_player_hand)
				table.insert(new_player_hand,p)
				b = play_round(new_player_hand, new_computer_hand,player_score, computer_score + c)
			else
				table.remove(new_player_hand,pi)
				table.remove(new_computer_hand,ci)
				table.insert(new_computer_hand,p)
				a = play_round(new_player_hand,new_computer_hand,player_score + c,computer_score)
				table.remove(new_computer_hand)
				table.insert(new_computer_hand,c)
				b = play_round(new_player_hand, new_computer_hand, player_score + p, computer_score)
			end
			score = score + a + b
		end
		if score > best then
			best = score
			bi = ci
		end
		total = total + score
	end
	return total,bi
end

function copy_list(l)
	local n = {}
	for i,v in ipairs(l) do
		n[i] = v
	end
	return n
end

function has(l,v)
	for _,s in ipairs(l) do
		if s == v then
			return true
		end
	end
	return false
end

function total(ph,ch,ps,cs)
	local sum = 0
	for _,v in ipairs(ph) do
		sum = sum + v
	end
	for _,s in ipairs(ch) do
		sum = sum + s
	end
	sum = sum + ps
	sum = sum + cs
	return sum

end

main();
