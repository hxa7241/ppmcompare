#!/usr/bin/env lua
--------------------------------------------------------------------------------
--                                                                            --
--  PPM image comparator                                                      --
--  Harrison Ainsworth / HXA7241 : 2007                                       --
--                                                                            --
--  http://www.hxa.name/tools/                                                --
--                                                                            --
--  License: CC0 -- http://creativecommons.org/publicdomain/zero/1.0/         --
--                                                                            --
--------------------------------------------------------------------------------




--- constants ------------------------------------------------------------------

local IMAGE_MISMATCH           = "images not the same size"
local FILE_NOT_FOUND           = "file not found"
local IMAGE_FORMAT_INVALID     = "image format invalid"
local IMAGE_FILE_INCOMPLETE    = "image file incomplete"
local IMAGE_DIMENSIONS_INVALID = "image dimensions invalid"
--local IMAGE_FILE_TOO_LONG      = "image file too long"
local FILE_WRITE_FAILED        = "file write failed"

local IMAGE_COMMENT = "# PPM-Comparator Lua : HXA7241"
local GAMMA         = 0.45




--- functions ------------------------------------------------------------------

function checkValidity( width, height, maxval, filePathname )

   -- integer
   if (width ~= math.floor(width)) or (height ~= math.floor(height)) or
      (maxval ~= math.floor(maxval)) or
   -- in range
      (width < 1) or (height < 1) or
      (height > ((2 ^ 31 -1) / 3)) or (width > ((2 ^ 31 -1) / (height * 3))) or
      (maxval < 1) or (maxval > 255) then

      error( IMAGE_DIMENSIONS_INVALID .. ": " .. filePathname )

   end

end


--- Read a PPM into float [0,1] pixels.
---
--- @filePathname  String
--- @isGamma       Boolean whether to gamma decode
--- @return  { width= Number, height= Number, pixels= Table of Number fields }
---
function readPpm( filePathname, isGamma )

   local input = io.open( filePathname, "rb" )
   if not input then error( FILE_NOT_FOUND .. ": " .. filePathname ) end

   -- check id
   if "P6" ~= input:read( 2 ) then
      error( IMAGE_FORMAT_INVALID .. ": " .. filePathname )
   end

   -- read width, height, maxval
   function readNumber()

      -- skip blanks and comments
      repeat
         local c

         -- read chars until non blank
         repeat
            c = input:read( 1 )
            if not c then
               error( IMAGE_FILE_INCOMPLETE .. ": " .. filePathname )
            end
         until c:match( "%S" )
         local s, e = input:seek( "cur", -1 )
         if not s then error( e .. ": " .. filePathname ) end

         -- if comment-start then read chars until after newline
         -- else exit loop
         if "#" == c then input:read("*l") else break end
      until false

      -- read number
      return input:read( "*n" )
   end
   local width, height, maxval = readNumber(), readNumber(), readNumber()

   -- skip single blank
   input:seek( "cur", 1 )

   -- check validity
   checkValidity( width, height, maxval, filePathname )

   -- read pixels
   local pixels = {}
   for i = 1, (width * height * 3) do
      local c = input:read( 1 )
      if not c then error( IMAGE_FILE_INCOMPLETE .. ": " .. filePathname ) end

      -- rescale to [0,1]
      local channel = c:byte() / 255

      -- gamma decode
      if isGamma then channel = math.pow( channel, (1.0 / GAMMA) ) end

      table.insert( pixels, channel )
   end

   -- check file not too long
   --if input:read( 1 ) then
   --   error( IMAGE_FILE_TOO_LONG .. ": " .. filePathname )
   --end

   input:close()

   return { width= width, height= height, pixels= pixels }

end


--- Write float [0,1] pixels to a PPM.
---
--- @filePathname  String
--- @width         Number integer >= 1 and <= 10000
--- @height        Number integer >= 1 and <= 10000
--- @pixels        Table of Number fields, length width * height * 3
--- @isGamma       Boolean whether to gamma encode
---
function writePpm( filePathname, width, height, pixels, isGamma )

   local MAXVAL = 255

   -- check validity
   checkValidity( width, height, MAXVAL, filePathname )

   -- open file
   local output, e = io.open( filePathname, "wb" )
   if not output then error( e .. ": " .. filePathname ) end

   -- write ID and comment
   if not output:write( "P6", "\n", IMAGE_COMMENT, "\n") then
      error( FILE_WRITE_FAILED .. ": " .. filePathname )
   end

   -- write width, height, maxval
   if not output:write( width,  " ", height, "\n", MAXVAL, "\n" ) then
      error( FILE_WRITE_FAILED .. ": " .. filePathname )
   end

   -- write pixels
   for _, channel in ipairs(pixels) do

      -- clamp to [0,1]
      channel = math.min( math.max( channel, 0.0 ), 1.0 )

      -- gamma encode
      if isGamma then channel = math.pow( channel, GAMMA ) end

      -- quantize
      local quantized = math.floor( (channel * MAXVAL) + 0.5 )

      -- output as byte
      if not output:write( string.char( quantized ) ) then
         error( FILE_WRITE_FAILED .. ": " .. filePathname )
      end
   end

   output:close()

end




--- entry point ----------------------------------------------------------------

-- check if help message needed
if (not arg[1]) or (arg[1] == "-?") or (arg[1] == "--help") then

   -- print help message
   print( "\n  PPM Comparator  2007-12-23\n" ..
      "  Copyright (c) 2007, Harrison Ainsworth / HXA7241.\n\n" ..
      "usage:\n" ..
      "  ppmcomparator {--help|-?}\n" ..
      "  ppmcomparator image1FilePathName image2FilePathName\n" ..
      "\n" ..
      "Reads images as [0,1] pixels,\n" ..
      "gives min, max, mean differences,\n" ..
      "writes difference image of image1 - image2 + 128\n"
   )

-- execute
else

   print( "\n  PPM Comparator  :  HXA7241\n" )

   -- read input images
   local images = { readPpm(arg[1], true), readPpm(arg[2], true) }
   if (images[1].width  ~= images[2].width) or
      (images[1].height ~= images[2].height) or
      (#(images[1]) ~= #(images[2])) then
      error( IMAGE_MISMATCH )
   end

   -- compare images
   local difference = { width = images[1].width, height = images[1].height,
      pixels = {} }
   local difMin, difMax, difSum, difMean = 0, 0, 0, 0
   for i = 1, (difference.width * difference.height * 3) do
      local dif = images[1].pixels[i] - images[2].pixels[i]

      difference.pixels[i] = math.min( math.max( (dif + 0.5), 0 ), 1 )

      if dif < difMin then difMin = dif end
      if dif > difMax then difMax = dif end
      difSum = difSum + math.abs(dif)
   end
   if (difference.width * difference.height * 3) > 0 then
      difMean = difSum / (difference.width * difference.height * 3)
   else
      difMean = 0
   end

   -- write difference image
   writePpm( "difference-" .. os.time() .. ".ppm",
      difference.width, difference.height, difference.pixels, false )

   -- print stats
   print( "min:  " .. difMin .. "\nmax:  " .. difMax ..
      "\nmean: " .. difMean )

end
