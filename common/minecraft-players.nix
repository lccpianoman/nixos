# Whitelist and operators shared by every Minecraft server in this repo
# (nixcraft, calliope), so the two lists cannot drift. Plain data: `import` it.
rec {
  whitelist = {
    ScoreSpy       = "8c98c93b-e269-446e-8df8-23c8a82b5397";
    ScathaPro      = "d94be89d-b808-481d-a1dd-ed9b564d8e8d";
    Samwy          = "92a17f3d-abd8-49f0-9342-797dbf1f2cf0";
    bedwargod      = "b0af0d0b-6760-48f5-bbac-5c5f15db0222";
    WormPro        = "4cd5441f-94b7-4bbf-a809-7578eb6bd5b4";
    coolrunnings22 = "72ec6d21-f772-4db3-9e8f-fffc45fa4c76";
    Golden_Wraith  = "5e584a8e-c3da-4c99-ad04-ea1696334cf5";
  };

  operators = {
    inherit (whitelist) ScoreSpy ScathaPro;
  };
}
