module UI ( module UI
          , module Graphics.DrawingCombinators
          , module Graphics.UI.SDL.Keysym
          , SDL.Event(..)
          , SDL.delay -- , SDL.getTicks
          ) where

import Control.Concurrent
import Control.Concurrent.STM
import Control.Concurrent.STM.TChan
import Control.Concurrent.STM.TVar
import Control.Concurrent.STM.TMVar
import Data.Monoid

import qualified Graphics.DrawingCombinators as Draw
import Graphics.DrawingCombinators ((%%), Color(..), Any(..), R, Affine, R2)
import qualified Graphics.UI.SDL as SDL
import Graphics.UI.SDL.Keysym
import qualified Graphics.Rendering.OpenGL.GL as GL

import Vec
import Game
import Core
import Util

initUI :: IO ()
initUI = initSDL

killUI :: IO ()
killUI = SDL.quit

initSDL :: IO ()
initSDL = do SDL.init [SDL.InitTimer, SDL.InitVideo]
             SDL.setVideoMode 800 800 32 [SDL.OpenGL] 
             return ()

newEvents :: IO [SDL.Event]
newEvents = repeatWhileM (/= SDL.NoEvent) SDL.pollEvent


keypresses :: SDL.Event -> Maybe SDLKey
keypresses (SDL.KeyDown sym) = Just $ SDL.symKey sym
keypresses _ = Nothing

translateEvent :: SDL.Event -> SDL.Event
translateEvent (SDL.KeyDown sym)
  | (SDL.symKey sym) == SDLK_ESCAPE = SDL.Quit
translateEvent e = e

-- Runs the given action, returns the number of ticks elapsed
timeAction :: IO () -> IO Ticks
timeAction x = (subtract <$> SDL.getTicks) <* x <*> SDL.getTicks

translate, scale :: Pt2 R -> Affine
translate = Draw.translate . toPair
scale = uncurry Draw.scale . toPair

rectangle :: R2 -> R2 -> Draw.Image Any
rectangle (x,y) (w,h) = Draw.convexPoly [(x, y), (x,y+h), (x+w,y+h), (x+w,y)]


doRendering :: Draw.Image a -> IO ()
doRendering r = do GL.clear [GL.ColorBuffer]
                   Draw.clearRender $ r
                   SDL.glSwapBuffers


renderGame :: Game -> Draw.Image Any
renderGame g = translate (pt2 (-1) 1)
           %% scale (pt2 2 (-2) / (fromIntegral <$> levelDim g))
           %% doCrap
  where doCrap = mconcat $ drawPlayer : drawField
        drawField = map drawDirt $ 
                    concat $ 
                    zipWith (\y t -> zipWith (\x d -> (pt2 x y, d)) [0..] t) [0..] $ (terrain.level) g
        drawDirt (pos, dirt) = translate pos %% Draw.tint (dirtColor dirt) (rectangle (0,0) (1,1))  
        dirtColor Dirt = Color 0.5 0.25 0.1 1
        dirtColor Wall = Color 0.25 0.25 0.25 1
        drawPlayer = (translate $ fromIntegral <$> player g) 
                  %% Draw.tint (Color 0 1 0 1) (rectangle (0,0) (1,1))


