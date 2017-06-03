module Emmet.Parser where

import Prelude

import Control.Alt ((<|>))
import Control.Lazy (defer)
import Data.Array as Array
import Data.Char.Unicode (isDigit)
import Data.Foldable (class Foldable)
import Data.Int as Int
import Data.List (many, some)
import Data.Maybe (maybe)
import Data.String (fromCharArray)
import Emmet.Types (Attribute(..), Emmet, child, element, multiplication, sibling)
import Text.Parsing.Parser (Parser, fail)
import Text.Parsing.Parser.Combinators as P
import Text.Parsing.Parser.String (char, satisfy)
import Text.Parsing.Parser.Token (alphaNum)

type EmmetParser a = Parser String a

fromCharList :: forall f. Foldable f => f Char -> String
fromCharList = fromCharArray <<< Array.fromFoldable

parseElementName :: EmmetParser String
parseElementName = fromCharList <$> some alphaNum

parseChild :: Emmet -> EmmetParser Emmet
parseChild e = child e <$> (char '>' *> parseEmmet)

parseSibling :: Emmet -> EmmetParser Emmet
parseSibling e = sibling e <$> (char '+' *> parseEmmet)

parseMultiplication :: Emmet -> EmmetParser Emmet
parseMultiplication e = do
  sInt <- fromCharList <$> (char '*' *> some (satisfy isDigit))
  repetitions <- maybe (fail "Failed to parse Multiplication number") pure (Int.fromString sInt)
  pure (multiplication e repetitions)

parseClass :: EmmetParser Attribute
parseClass = char '.' *> (Class <<< fromCharList <$> some alphaNum)

parseId :: EmmetParser Attribute
parseId = char '#' *> (Id <<< fromCharList <$> some alphaNum)

parseElement :: EmmetParser Emmet
parseElement = element <$> parseElementName <*> many (parseClass <|> parseId)

parseEmmet :: EmmetParser Emmet
parseEmmet = do
  root <- (defer \_ -> P.between (char '(') (char ')') parseEmmet) <|> parseElement
  P.choice
     [ defer \_ -> parseChild root
     , defer \_ -> parseSibling root
     , defer \_ -> do
          e <- parseMultiplication root
          P.choice
            [ defer \_ -> parseChild e
            , defer \_ -> parseSibling e
            , pure e
            ]
     , pure root
     ]