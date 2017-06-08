
module Test.Unicode(main) where

import Development.Shake
import Development.Shake.FilePath
import Test.Type
import General.GetOpt
import Control.Exception.Extra
import Control.Monad


-- | Decode a dull ASCII string to certain unicode points, necessary because
--   withArgs (even the UTF8 version) throws an encoding error on the > 256 code points
decode :: String -> String
decode ('e':'^':xs) = '\xEA' : decode xs -- Latin Small Letter E With Circumflex
decode (':':')':xs) = '\x263A' : decode xs -- White Smiling Face
decode (x:xs) = x : decode xs
decode [] = []

data Arg = Prefix String | Want String
opts =
    [Option "" ["prefix"] (ReqArg (Right . Prefix) "") ""
    ,Option "" ["want"] (ReqArg (Right . Want) "") ""]

main = shakeTest test opts $ \xs -> do
    let obj = id
    let pre = last $ "" : [decode x | Prefix x <- xs :: [Arg]]
    want [decode x | Want x <- xs]

    obj (pre ++ "dir/*") %> \out -> do
        let src = takeDirectory (takeDirectory out) </> takeFileName out
        copyFile' src out

    obj (pre ++ ".out") %> \out -> do
        a <- readFile' $ obj $ pre ++ "dir" </> pre <.> "source"
        b <- readFile' $ obj pre <.> "multi1"
        writeFile' out $ a ++ b

    map obj ["*.multi1","*.multi2"] &%> \[m1,m2] -> do
        b <- doesFileExist $ m1 -<.> "exist"
        writeFile' m1 $ show b
        writeFile' m2 $ show b


test build = do
    let obj = id
    build ["clean"]
    -- Useful, if the error message starts crashing...
    -- IO.hSetEncoding IO.stdout IO.char8
    -- IO.hSetEncoding IO.stderr IO.char8
    forM_ ["normal","e^",":)","e^-:)"] $ \pre -> do
        let ext x = obj $ decode pre <.> x
        res <- try_ $ writeFile (ext "source") "x"
        case res of
            Left err ->
                putStrLn $ "WARNING: Failed to write file " ++ pre ++ ", skipping unicode test (LANG=C ?)"
            Right _ -> do
                build ["--prefix=" ++ pre, "--want=" ++ pre <.> "out", "--sleep"]
                assertContents (ext "out") $ "x" ++ "False"
                writeFile (ext "source") "y"
                build ["--prefix=" ++ pre, "--want=" ++ pre <.> "out", "--sleep"]
                assertContents (ext "out") $ "y" ++ "False"
                writeFile (ext "exist") ""
                build ["--prefix=" ++ pre, "--want=" ++ pre <.> "out"]
                assertContents (ext "out") $ "y" ++ "True"
