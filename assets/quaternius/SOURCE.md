# Quaternius assets — source

Models by **Quaternius** (https://quaternius.com), license **CC0 1.0** (public domain, no attribution required; credited anyway): https://creativecommons.org/publicdomain/zero/1.0/

| Pack | Page | Files used | Archive SHA-256 |
|---|---|---|---|
| Ultimate Animated Character Pack (Nov 2019) | https://quaternius.com/packs/ultimatedanimatedcharacter.html | `characters/*.fbx` (Knight_Male, Wizard, Elf, Goblin_Male, Viking_Male) | `66c7686f443bc2dbcf4f278aa725a3562ee6d2e592c28798c9061c74ed3ad827` |
| Skeleton, Zombie, Ghost (single models, CC0 1.0 on their pages) | [Skeleton](https://poly.pizza/m/yq5ATpujSt), [Zombie](https://poly.pizza/m/VlXjG0N8Eg), [Ghost](https://poly.pizza/m/Iip30bDHmu) on Poly Pizza | `monsters/Skeleton.glb`, `monsters/Zombie.glb`, `monsters/Ghost.glb` | — (downloaded one by one, see the file hashes) |
| Wooden Bow, Sword, Staff (single models, CC0 1.0 on their pages) | [Wooden Bow](https://poly.pizza/m/QnpqjLSKFU), [Sword](https://poly.pizza/m/9lLmH8Et4K), [Staff](https://poly.pizza/m/PnGRvO4Lwd) on Poly Pizza | `props/WoodenBow.glb` (the Ranger's and the Skeleton Archer's), `props/Sword.glb` (the Knight's), `props/Staff.glb` (the Mage's) | — (see the file hashes) |
| Modular Dungeon Pack (Jan 2018) | https://quaternius.com/packs/medievaldungeon.html | `dungeon/*.fbx` (Barrel, Chest, Rock1, Rock2, Rock3) | `6933ae4b51a256a6fbc08d9c2d1c3a80dbeca04c12385ffbbb365c26848130bd` |

The monsters and the bow were downloaded during milestone 8 as `.glb` files from Poly Pizza's static storage (`static.poly.pizza/<id>.glb`, linked from each page), checked (glTF binary, embedded textures and buffers, no external URIs or extensions) and renamed, otherwise unmodified.

The packs were downloaded by the project owner from the Google Drive folders linked on those pages, inspected in a scratch folder outside the repo (only `.fbx` files, verified FBX headers, no scripts or archives inside) and only the files above were copied here, unmodified.

## File hashes (SHA-256)

```
02948bf6ff8d441a348cc1cb3a7fb42bc3625cc9135c23770a484e732ce4646a  characters/Elf.fbx
ce92e034493a2866c2427419cf627b0ac817236077f3c53e671d54162dfafeae  characters/Goblin_Male.fbx
fd323fbc4962a9b94ab58d303bbc92ead7228393b735a95d98a8509e33747e3f  characters/Knight_Male.fbx
022d068d0308f485e372398c73c9d8a90a76b1603b3dd36dc09b29572c005db5  characters/Viking_Male.fbx
a0515645954945a9029bf2db4b4fa120f24e9516402987bdc29c7b570fb9f957  characters/Wizard.fbx
5b3e91624644ee56e38aad9a129bfb158cb2db37799dc0a4447c77b7f176d349  dungeon/Barrel.fbx
d60da3709e7ab994853093afc7544f66ba770159c71521b03906598a6ccc69cb  dungeon/Chest.fbx
d92cef9055caab90ec661be97b2b4263fedb7c824fc0c910edd260ea99e46c74  dungeon/Rock1.fbx
e2e77586004510a9a9302f7120e08339b9467da782b4bc47d350e0766da9a468  dungeon/Rock2.fbx
6699ba6f93ba850905b774a59083c3b351c823141473ff62cb3d895a521af509  dungeon/Rock3.fbx
4ed7656e2155d47b7d5fe08f31a7e764d79255f477d90040e4472552d7d5ac68  monsters/Ghost.glb
80be43fa7bd961faef44fa82a8067048a48ba329d65fed663a184ee73a18aacb  monsters/Skeleton.glb
3afd2837b117f264afd037a350759b96d6f837fc9b381cca35cf6796b4bab09d  monsters/Zombie.glb
8c0dbd0bc20dc586163124c745b10852a6f215b646084dc74955e92f77824401  props/Staff.glb
ebf6a37a1570d3c01822f3e65ae3dca76a76fcc1943ed33bdcd90dc75329218a  props/Sword.glb
0aca54204443e70af43a9cc7e98c5c9ae42c938595078c801f2303fedd2f6d8f  props/WoodenBow.glb
```
