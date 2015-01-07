using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;

namespace CardsLevelDesigner
{
    [Serializable]
    class Obstacle
    {
        [NonSerialized]
        public Rectangle Rect;
        public int x
        {
            set
            {
                Rect.X = value;
            }
            get
            {
                return Rect.X;
            }
        }
        public int y
        {
            set
            {
                Rect.Y = value;
            }
            get
            {
                return Rect.Y;
            }
        }

        public int width
        {
            set
            {
                Rect.Width = value;
            }
            get
            {
                return Rect.Width;
            }
        }

        public int height
        {
            set
            {
                Rect.Height = value;
            }
            get
            {
                return Rect.Height;
            }
        }

        public int type;
        public double gravity;
    }
}
