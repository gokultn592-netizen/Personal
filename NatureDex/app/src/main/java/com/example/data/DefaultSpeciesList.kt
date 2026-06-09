package com.example.data

data class DefaultSpecies(
    val id: Int,
    val name: String,
    val scientificName: String,
    val category: String, // Animals, Birds, Fish, Insects, Reptiles, Plants
    val rarity: String, // Common, Uncommon, Rare, Legendary
    val threatLevel: String, // None, Low, Medium, High, Deadly
    val imageUrl: String,
    val habitat: String,
    val diet: String,
    val distribution: String,
    val iucnStatus: String, // Least Concern, Vulnerable, Endangered, Critically Endangered
    val funFacts: List<String>,
    val nativeToTamilNadu: Boolean = false
)

object DefaultSpeciesList {
    val list = listOf(
        // --- ANIMALS ---
        DefaultSpecies(
            id = 101,
            name = "Nilgiri Tahr",
            scientificName = "Nilgiritragus hylocrius",
            category = "Animals",
            rarity = "Rare",
            threatLevel = "None",
            imageUrl = "https://static.inaturalist.org/photos/27061356/medium.jpg",
            habitat = "Montane grasslands and rocky cliffs",
            diet = "Herbivorous (grasses and herbs)",
            distribution = "Western Ghats of Tamil Nadu and Kerala",
            iucnStatus = "Endangered",
            funFacts = listOf(
                "It is the State Animal of Tamil Nadu.",
                "Adult males develop a light grey area on their backs, earning them the nickname 'Saddlebacks'.",
                "They are exceptionally agile and can traverse near-vertical mountain slopes relative to their size."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 102,
            name = "Bengal Tiger",
            scientificName = "Panthera tigris tigris",
            category = "Animals",
            rarity = "Legendary",
            threatLevel = "Deadly",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/13207883/medium.jpg",
            habitat = "Tropical forests, swamps, and grasslands",
            diet = "Carnivorous (Deers, wild boars, gaurs)",
            distribution = "India, Bangladesh, Nepal, Bhutan",
            iucnStatus = "Endangered",
            funFacts = listOf(
                "Each Bengal Tiger's stripe pattern is completely unique, like human fingerprints.",
                "They are excellent swimmers and frequently wade or hunt in deep waterways to cool off.",
                "A tiger's roar can be heard from over 3 kilometers (1.8 miles) away at night."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 103,
            name = "Grizzled Giant Squirrel",
            scientificName = "Ratufa macroura",
            category = "Animals",
            rarity = "Rare",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/21130446/medium.jpg",
            habitat = "Riparian forests and tall canopy trees",
            diet = "Fruits, nuts, bark, and insects",
            distribution = "Southern India and Sri Lanka",
            iucnStatus = "Near Threatened",
            funFacts = listOf(
                "They live in tree canopies, rarely descending to the forest floor.",
                "They construct massive globe-shaped nests ('dreys') in tall branches.",
                "Tamil Nadu hosts a dedicated sanctuary for this species in Srivilliputhur."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 104,
            name = "Indian Elephant",
            scientificName = "Elephas maximus indicus",
            category = "Animals",
            rarity = "Rare",
            threatLevel = "High",
            imageUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/9/98/Elephas_maximus_%28Bandipur%29.jpg/960px-Elephas_maximus_%28Bandipur%29.jpg",
            habitat = "Scrub forests, grass lands, and deciduous forests",
            diet = "Herbivorous (roots, grasses, fruits, bark)",
            distribution = "Across mainland Asia and Southern India",
            iucnStatus = "Endangered",
            funFacts = listOf(
                "They can spend up to 19 hours a day eating to fuel their giant bodies.",
                "Their trunks contain over 40,000 individual muscles, making them highly dexterous.",
                "Elephants exhibit deep emotional capacity, mourn their dead, and display extreme empathy."
            ),
            nativeToTamilNadu = true
        ),

        // --- BIRDS ---
        DefaultSpecies(
            id = 201,
            name = "Emerald Dove",
            scientificName = "Chalcophaps indica",
            category = "Birds",
            rarity = "Uncommon",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/90707654/medium.jpg",
            habitat = "Wet tropical forests and damp woodlands",
            diet = "Seeds, fallen fruits, and termites",
            distribution = "Indian subcontinent, Southeast Asia, Australia",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "It is the State Bird of Tamil Nadu.",
                "Its wings showcase a striking, metallic emerald-green coloration.",
                "Unlike standard pigeons/doves, the Emerald Dove runs swiftly on the forest floor rather than flying immediately."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 202,
            name = "Indian Peafowl (Peacock)",
            scientificName = "Pavo cristatus",
            category = "Birds",
            rarity = "Common",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/165318600/medium.jpg",
            habitat = "Dry semi-desert grasslands, deciduous forests, and near villages",
            diet = "Omnivorous (seeds, insects, small reptiles)",
            distribution = "Native to South Asia, introduced globally",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "It is the National Bird of India.",
                "Only the males (peacocks) boast the magnificent iridescent tail train used in courtship.",
                "They have sharp spurs on their heels, which they use to defend themselves from ground predators."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 203,
            name = "Great Hornbill",
            scientificName = "Buceros bicornis",
            category = "Birds",
            rarity = "Legendary",
            threatLevel = "None",
            imageUrl = "https://static.inaturalist.org/photos/13353681/medium.jpg",
            habitat = "Primary dense evergreen rainforests",
            diet = "Frugivorous (figs, small mammals, nest birds)",
            distribution = "Western Ghats of India and Southeast Asia",
            iucnStatus = "Vulnerable",
            funFacts = listOf(
                "They have a massive yellow-orange 'casque' on top of their large bill, which functions as a vocal amplifier.",
                "Great Hornbirds are monogamous and pair up for life.",
                "The female nests inside a hollow tree trunk, sealing herself completely with mud for safety."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 204,
            name = "Malabar Whistling Thrush",
            scientificName = "Myophonus horsfieldii",
            category = "Birds",
            rarity = "Uncommon",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/59329256/medium.jpg",
            habitat = "Rocky rushing mountain streams and wet forests",
            diet = "Snails, aquatic insects, crabs, frogs",
            distribution = "Western Ghats of India",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "Known popularly as the 'Whistling Schoolboy' due to its musical whistle at dawn.",
                "Its calls sound remarkably human, mimicking off-key student tunes.",
                "They are excellent at catching fresh crabs along mountain streams."
            ),
            nativeToTamilNadu = true
        ),

        // --- REPTILES ---
        DefaultSpecies(
            id = 301,
            name = "Spectacled Cobra",
            scientificName = "Naja naja",
            category = "Reptiles",
            rarity = "Uncommon",
            threatLevel = "Deadly",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/97106278/medium.jpg",
            habitat = "Plains, agricultural fields, and urban outskirts",
            diet = "Rodents, frogs, birds, and other snakes",
            distribution = "Native to the Indian Subcontinent",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "It boasts an iconic 'spectacle' mark on the rear of its expanded hood.",
                "Its neurotoxic venom attacks the nervous system and can lock lung movement within hours.",
                "This cobra is highly revered in Indian mythology and is closely associated with Lord Shiva."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 302,
            name = "Indian Star Tortoise",
            scientificName = "Geochelone elegans",
            category = "Reptiles",
            rarity = "Rare",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/109310050/medium.jpg",
            habitat = "Dry scrub forests and grasslands",
            diet = "Herbivorous (grasses, succulents, fallen leaves)",
            distribution = "India, Pakistan, Sri Lanka",
            iucnStatus = "Vulnerable",
            funFacts = listOf(
                "Its carapace features gorgeous, radiating yellow-and-black star patterns.",
                "They are highly threatened by illegal global wildlife trafficking due to high demand.",
                "Unlike aquatic turtles, star tortoises lack webbed feet and cannot swim."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 303,
            name = "Gharial",
            scientificName = "Gavialis gangeticus",
            category = "Reptiles",
            rarity = "Legendary",
            threatLevel = "Low",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/518604067/medium.jpg",
            habitat = "Deep, fast-flowing freshwater rivers with sandy banks",
            diet = "Piscivorous (strictly fish eaters)",
            distribution = "Northern rivers of India (Chambal and Ganges)",
            iucnStatus = "Critically Endangered",
            funFacts = listOf(
                "They have extraordinarily long, thin snouts filled with over a hundred needle-like teeth.",
                "Adult males grow a large bulbous growth ('ghara' - meaning pot) on the tip of their snout.",
                "Gharials are highly aquatic and have very weak legs on land."
            ),
            nativeToTamilNadu = false
        ),
        DefaultSpecies(
            id = 304,
            name = "King Cobra",
            scientificName = "Ophiophagus hannah",
            category = "Reptiles",
            rarity = "Legendary",
            threatLevel = "Deadly",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/307874083/medium.jpeg",
            habitat = "Dense rain forests, bamboo clusters, and swamps",
            diet = "Ophiophagous (exclusively feeds on other snakes!)",
            distribution = "India and across Southeast Asia",
            iucnStatus = "Vulnerable",
            funFacts = listOf(
                "It is the longest venomous snake in the world, growing up to 5.8 meters (19 feet).",
                "It is the only snake species globally that builds nests to lay and protect its eggs.",
                "A single bite can deliver enough venom to kill a full-grown Asian Elephant in 3 hours."
            ),
            nativeToTamilNadu = true
        ),

        // --- FISH ---
        DefaultSpecies(
            id = 401,
            name = "Deccan Mahseer",
            scientificName = "Tor khudree",
            category = "Fish",
            rarity = "Rare",
            threatLevel = "None",
            imageUrl = "https://static.inaturalist.org/photos/181398067/medium.jpeg",
            habitat = "Fast-flowing rocky rivers and mountain streams",
            diet = "Omnivorous (aquatic insects, small fish, algae)",
            distribution = "Western Ghats, River Cauvery in Tamil Nadu",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "Known as the 'Tiger of the Water' due to its extreme fighting spirit on fishing hooks.",
                "They act as excellent ecological indicators for clear, well-oxygenated mountain streams.",
                "The Cauvery River near Hogenakkal Falls and Bheemeshwari is highly famous for Mahseer sightings."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 402,
            name = "Climbing Perch",
            scientificName = "Anabas testudineus",
            category = "Fish",
            rarity = "Common",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/52464343/medium.jpg",
            habitat = "Canals, ponds, swamps, and estuary borders",
            diet = "Invertebrates, algae, and insect larvae",
            distribution = "South and Southeast Asia",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "It possesses an accessory breathing organ (labyrinth) that lets it breathe air directly.",
                "They can 'walk' across wet land for several hours using their spiny gill plates.",
                "Known to hibernate inside damp mud beds during dry seasons."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 403,
            name = "Red-Line Torpedo Barb",
            scientificName = "Sahyadria denisonii",
            category = "Fish",
            rarity = "Rare",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/80515486/medium.jpg",
            habitat = "Torrential mountain torrents",
            diet = "Algae, detritus, and tiny crustaceans",
            distribution = "Western Ghats of Southern India",
            iucnStatus = "Endangered",
            funFacts = listOf(
                "Known as the 'Denison Barb' or 'Miss Kerala' in the international aquarium trade.",
                "Features a beautiful, vibrant red stripe running along its metallic silver body.",
                "Highly threatened due to over-collection and natural river logging."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 404,
            name = "Whale Shark",
            scientificName = "Rhincodon typus",
            category = "Fish",
            rarity = "Legendary",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/519729370/medium.jpg",
            habitat = "Deep open oceans and tropical coastal waters",
            diet = "Filter-feeding (Plankton, krill, fish eggs)",
            distribution = "Global warm oceanic environments",
            iucnStatus = "Endangered",
            funFacts = listOf(
                "It is the largest confirmed fish species living today, growing up to 18 meters (60 feet).",
                "Despite their colossal size, they are gentle giants and pose no danger to human swimmers.",
                "Every whale shark has unique spot patterns behind its gills, like starry constellations."
            ),
            nativeToTamilNadu = false
        ),

        // --- INSECTS ---
        DefaultSpecies(
            id = 501,
            name = "Common Rose Butterfly",
            scientificName = "Pachliopta aristolochiae",
            category = "Insects",
            rarity = "Common",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/12261707/medium.jpg",
            habitat = "Gardens, scrub forests, and evergreen woods",
            diet = "Nectar from various flowering plants",
            distribution = "South and Southeast Asia",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "It showcases spectacular red-and-black contrasts alongside detailed white spots.",
                "Its body contains toxic chemicals (Aristolochic acids) acquired from its host plant during larvae stage.",
                "Due to its bad taste, other non-toxic butterflies adapt mimics to protect themselves."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 502,
            name = "Indian Honey Bee",
            scientificName = "Apis cerana indica",
            category = "Insects",
            rarity = "Common",
            threatLevel = "Medium",
            imageUrl = "https://upload.wikimedia.org/wikipedia/commons/b/b6/Apiscerana.jpg",
            habitat = "Forest hollows, gardens, crevices",
            diet = "Pollen and flower nectar",
            distribution = "South Asia",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "Indispensable pollinators responsible for 30% of Indian wildflowers and crops.",
                "They communicate remote food sources using complex 'waggle dances'.",
                "A honey bee hive operates under a single powerful queen with up to 50,000 workers."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 503,
            name = "Atlas Moth",
            scientificName = "Attacus atlas",
            category = "Insects",
            rarity = "Rare",
            threatLevel = "None",
            imageUrl = "https://static.inaturalist.org/photos/416188682/medium.jpg",
            habitat = "Subtropical dry deciduous forests and rain woods",
            diet = "Caterpillars eat leaves; adult moths lack mouths and eat nothing!",
            distribution = "India and East-Southeast Asia",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "Boasts the largest wing surface area of any insect, stretching up to 30 centimeters (12 inches).",
                "The outer tips of its wings look remarkably like cobra heads to frighten predators.",
                "They live as adults for only 1 to 2 weeks, relying entirely on stored larval fat."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 504,
            name = "Praying Mantis",
            scientificName = "Hierodula coarctata",
            category = "Insects",
            rarity = "Uncommon",
            threatLevel = "Low",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/29918596/medium.jpg",
            habitat = "Grasslands, gardens, and canopy bushes",
            diet = "Carnivorous (smaller insects, spiders, can catch lizards!)",
            distribution = "Tropical and template zones globally",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "They are the only insects capable of rotating their triangular heads 180 degrees.",
                "Their forelegs are modified into lethal, spiked traps used for capturing prey at near-instant speeds.",
                "They are famous for female sexual cannibalism (eating the male after mating)."
            ),
            nativeToTamilNadu = true
        ),

        // --- PLANTS ---
        DefaultSpecies(
            id = 601,
            name = "Gloriosa Lily (Flame Lily)",
            scientificName = "Gloriosa superba",
            category = "Plants",
            rarity = "Uncommon",
            threatLevel = "Medium",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/31827544/medium.jpeg",
            habitat = "Thickets, woodlands, and dry scrublands",
            diet = "Photosynthesis (Autotroph)",
            distribution = "Tropical Africa and Asia",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "It is the State Flower of Tamil Nadu (known as Sengandhal).",
                "The flower looks like dancing yellow-red flames winding upward.",
                "All parts of the plant, especially the tuberous roots, contain highly toxic alkaloids (colchicine)."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 602,
            name = "Palmyra Palm",
            scientificName = "Borassus flabellifer",
            category = "Plants",
            rarity = "Common",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/37326538/medium.jpeg",
            habitat = "Arid dry lowlands and sandy shores",
            diet = "Photosynthesis",
            distribution = "Native to Indian Subcontinent and Southeast Asia",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "It is the State Tree of Tamil Nadu (known as Panai Maram).",
                "Almost every part of the tree has local utility - leaves for manuscripts, sap for palm wine/toddy, trunk for wood.",
                "It yields delicious translucent jelly seeds known as 'Nungu'."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 603,
            name = "Neem Tree",
            scientificName = "Azadirachta indica",
            category = "Plants",
            rarity = "Common",
            threatLevel = "None",
            imageUrl = "https://static.inaturalist.org/photos/70176803/medium.jpg",
            habitat = "Dry grasslands, agricultural hedges, and towns",
            diet = "Photosynthesis",
            distribution = "Native of Indian Subcontinent, widely grown in tropics",
            iucnStatus = "Least Concern",
            funFacts = listOf(
                "Its leaves provide exceptional antibacterial, antiviral, and antifungal antiseptic properties.",
                "Traditionally used in India in toothbrushes, skin care, and insecticides.",
                "Neem is considered a natural air purifier and a keystone plant in Ayurvedic medicine."
            ),
            nativeToTamilNadu = true
        ),
        DefaultSpecies(
            id = 604,
            name = "Sandalwood Tree",
            scientificName = "Santalum album",
            category = "Plants",
            rarity = "Legendary",
            threatLevel = "None",
            imageUrl = "https://inaturalist-open-data.s3.amazonaws.com/photos/30611222/medium.jpeg",
            habitat = "Dry deciduous forests and rocky hills",
            diet = "Hemiparasite (draws nutrients from roots of host plants)",
            distribution = "Southern India and Indonesia",
            iucnStatus = "Vulnerable",
            funFacts = listOf(
                "Its heartwood is incredibly fragrant and yields expensive aromatic essential oil.",
                "Sandalwood is a hemiparasite, grafting onto nearby trees for nitrogen and potassium.",
                "Highly protected by the state government; cutting or transport is subject to strict licensing laws."
            ),
            nativeToTamilNadu = true
        )
    )
}

