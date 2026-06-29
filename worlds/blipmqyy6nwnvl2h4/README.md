# Crystal Pickaxe Valley

A tiny multiplayer-ready Blip voxel valley where friends can walk around together, swing pickaxes, farm glowing crystal nodes, collect stone and gold, then reach a neon market pad to sell resources.

Original prompt: Build a tiny Blip world where friends can walk around, use pickaxes, farm crystals, collect resources, and reach a glowing market pad.

Physics: movement 44, jump 72, reach 8, camera 46

Rules: sell 5+ resources for 3x coins; win condition build_and_sell_resources

Effects: neon; tool_swing, resource_pop, market_burst, coin_ping, crystal_glow

Code: structured_no_raw_lua; mechanics resource_loop, market_sale, hud_feedback, social_join_scaffold, pickaxe_action, resource_respawn, goal_pad_feedback, speed_tuning; hooks Client.OnStart, Client.Tick, Client.Action1, Client.Action2

Planner: surplus/gpt-5.5
