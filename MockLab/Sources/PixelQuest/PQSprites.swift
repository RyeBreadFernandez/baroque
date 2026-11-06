import SwiftUI

// Hand-authored sprites. All original: an owl sage, pines, quest icons, the pointing glove.

enum Sprites {
    // MARK: Trees
    private static let pineKey: [Character: C] = ["a": .pine3, "b": .pine2, "c": .pine1, "d": .pine0, "t": .earth1, "o": .pine0]
    private static let darkPineKey: [Character: C] = ["a": .teal2, "b": .pine1, "c": .pine0, "d": .teal0, "t": .earth0, "o": .teal0]

    private static let pineL = """
    ....b....
    ...abc...
    ...abc...
    ..abbcc..
    ...abc...
    ..abbcc..
    .abbbccc.
    ..abbcc..
    .abbbccc.
    abbbbcccd
    ...dtd...
    ....t....
    """
    private static let pineM = """
    ...b...
    ..abc..
    ..abc..
    .abbcc.
    ..abc..
    .abbcc.
    abbbccd
    ..dtd..
    """
    private static let pineS = """
    ..b..
    .abc.
    .abc.
    abbcc
    .abc.
    abbcd
    ..t..
    """
    private static let pineXS = """
    .b.
    .b.
    abc
    abc
    .t.
    """

    static let pines: [Sprite] = [Sprite(pineL, pineKey), Sprite(pineM, pineKey), Sprite(pineM, pineKey), Sprite(pineS, pineKey)]
    static let smallPines: [Sprite] = [Sprite(pineM, pineKey), Sprite(pineS, pineKey), Sprite(pineS, pineKey)]
    static let darkPines: [Sprite] = [Sprite(pineM, darkPineKey), Sprite(pineS, darkPineKey), Sprite(pineS, darkPineKey), Sprite(pineXS, darkPineKey)]
    static let tinyPines: [Sprite] = [Sprite(pineS, darkPineKey), Sprite(pineXS, darkPineKey), Sprite(pineXS, darkPineKey)]

    // MARK: The owl sage (the NPC who speaks the quotes)
    static let owl = Sprite("""
    ..o........o..
    ..oo......oo..
    ..oLooooooBo..
    .oLBBBBBBBBdo.
    oLWWWBBBBWWWdo
    oWWPWWBBWWPWWo
    oWWPWWYYWWPWWo
    oLWWWBYYBWWWdo
    oLBBBBBBBBBBdo
    oLBccccccccBdo
    oLccVccccVcBdo
    oLcccVccVccBdo
    .oLccccccccdo.
    .oLLcVccVcddo.
    ..ooLLBBBddo..
    ...YY....YY...
    """, ["o": .ink, "L": .earth3, "B": .earth2, "d": .earth1, "c": .cream, "V": .earth3,
          "W": .gold3, "P": .ink, "Y": .gold1])

    // MARK: UI icons
    static let glove = Sprite("""
    ..oooo......
    .owwwwoooooo
    owwwwwwwwwwo
    owwwwwoooooo
    owwwwwwwo...
    owswwwwwo...
    owsswwwo....
    .ossssso....
    ..ooooo.....
    """, ["o": .ink, "w": .cream, "s": .creamD])

    static let star = Sprite("""
    ....o....
    ...oho...
    ooohhYooo
    ohhhYYYyo
    .ohYYYyo.
    ..oYYYo..
    .oYyoyYo.
    .oyo.oyo.
    .oo...oo.
    """, ["o": .ink, "h": .gold3, "Y": .gold2, "y": .gold1])

    private static let gemArt = """
    ..ooooo..
    .ohhRRro.
    ohhRRRRro
    oRRRRRrro
    .oRRRrro.
    ..oRRro..
    ...oro...
    ....o....
    """
    static let ruby = Sprite(gemArt, ["o": .ink, "h": .red2, "R": .red1, "r": .red0])
    static let sapphire = Sprite(gemArt, ["o": .ink, "h": .cream, "R": .teal3, "r": .teal2])

    static let bullet = Sprite("""
    ..o..
    .oco.
    ocCco
    .oco.
    ..o..
    """, ["o": .ink, "c": .creamD, "C": .cream])

    static let pebble = Sprite("""
    .oo.
    osso
    .oo.
    """, ["o": .ink, "s": .stone1])

    static let alert = Sprite("""
    oooo
    ohRo
    ohRo
    ohRo
    oRro
    oooo
    ohRo
    oooo
    """, ["o": .ink, "h": .red2, "R": .red1, "r": .red0])

    static func icon(for t: TaskItem) -> Sprite {
        switch t.priority {
        case .highest: return ruby
        case .high: return star
        case .medium: return sapphire
        case .none: return bullet
        case .low, .lowest: return pebble
        }
    }
}
