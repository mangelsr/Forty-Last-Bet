import os

# Define the suits and values for a Cuarenta deck
# (French deck minus 8, 9, 10)
suits = ["Spades", "Hearts", "Diamonds", "Clubs"]
# Values: 1 (Ace), 2-7, 11 (Jack), 12 (Queen), 13 (King)
values = [1, 2, 3, 4, 5, 6, 7, 11, 12, 13]

output_dir = "data/cards"
os.makedirs(output_dir, exist_ok=True)

for suit in suits:
    for value in values:
        name_map = {1: "Ace", 11: "Jack", 12: "Queen", 13: "King"}
        val_name = name_map.get(value, str(value))
        card_name = f"{val_name} of {suit}"
        file_name = f"{val_name.lower()}_{suit.lower()}.tres"
        path = os.path.join(output_dir, file_name)
        
        content = f"""[gd_resource type="Resource" script_class="CardData" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/scripts/resources/CardData.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
card_name = "{card_name}"
suit = "{suit}"
value = {value}
description = "{card_name} in the {suit} suit."
"""
        with open(path, "w") as f:
            f.write(content)

print(f"Generated 40 cards in {output_dir}")
