local supportedChamp = {
    Kalista = true,
    MissFortune = true,
    Lucian = true
}

if supportedChamp[Player.CharName] then
    LoadEncrypted("Mad"..Player.CharName)
end