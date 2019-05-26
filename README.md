# What this is:
This is a framework to allow modders to make wheeled or tracked vehicles in [Cortex Command](https://store.steampowered.com/app/209670/Cortex_Command/). It requires knowledge of Cortex Command modding including some knowledge of lua scripting, a fair understanding of ini configuration, and some ability to make sprites for your vehicle(s).

If you have any questions, you can contact me here or find me on the Cortex Command discord or Steam, under the name Gacyr.
********************************
# How to Use:

1. Download the VehicleFramework.lua file and place it in your rte

2. Create your sprites and ini for your vehicle. Look at the examples to walk through them. IMPORTANT: Make sure your sprites have no extra space around them, the objects should reach the edge of the sprite background where possible.

3. Load the VehicleFramework into the game so you can use it. This is done with 2 steps:  
	i. Add your rte to the lua package path. This is done by adding the following line to the top of your script (outside of any functions like Create):  
		`package.path = package.path..";YOUR_MOD.rte/?.lua";`  
	ii. Now load the VehicleFramework. This is done by adding the following line below the line you previously added (again, outside of any functions):  
		`require("VehicleFramework");`

4. Configure your Vehicle by making a vehicleConfig table (more on that below) in your Create function, and running the following code (note that you must keep the return value from createVehicle to keep it running):
	`self.vehicle = VehicleFramework.createVehicle(self, vehicleConfig);`

5. Continue to run the code for your Vehicle in your Update function by running the following code, preferably near the top of the Update function:
	`self.vehicle = VehicleFramework.updateVehicle(self, self.vehicle);`
	
NOTE: You can potentially skip step 3 and just do everything in your Update function, since that will create the vehicle if it's not fully created, but this may be more complex to do properly and is not advised.
********************************
# How to Configure your Vehicle:

Vehicle configuration is broken into 7 sections, each of which should be a subtable in the main vehicleConfig table. These sections are as follows:  
* general (\*)  
* chassis (\*)  
* suspension (\*)  
* wheel (\*)  
* tensioner  
* track  
* destruction  
	
The order of these sections doesn't matter, but it may be easiest to organize them in the order above. Sections marked with (\*)s are required and must have some amount of content, sections without can be skipped
For more information on the configuration options in these sections, see the *Vehicle Configuration Documentation*.

The minimum configuration for a vehicle would be as follows:

	vehicleConfig = {
		general = {
			maxSpeed = number
		},
		chassis = {
			size = Vector
		},
		suspension = {
			stiffness = number
		},
		wheel = {
			count = number
		}
	}
