using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace CardsLevelDesigner
{
    class Level
    {
        public LevelInfo[] levels;
    }
    [Serializable]
    class LevelInfo
    {
        public string name { get; set; }

        public int x { get; set; }

        public int y { get; set; }

        [JsonProperty(NullValueHandling = NullValueHandling.Ignore)]
        public TPoint from { get; set; }

        public TPoint to { get; set; }

        public int width { get; set; }

        public int height { get; set; }

        public int[] blocks { get; set; }

        public int[] stars { get; set; }

        public double gravity;

        public Obstacle[] obstacles { get; set; }
    }
}
