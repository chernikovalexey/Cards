using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Serialization;
using System.IO;
using Newtonsoft.Json;
using System.Net;

namespace CardsLevelDesigner
{
    public partial class Form1 : Form
    {
        class Rect
        {
            public Color Color;
            public Rectangle Rectangle;
        }
        public Form1()
        {
            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            var from = textBox1.Text;
            var to = textBox2.Text;
            Bitmap bmp;
            try
            {
                bmp = new Bitmap(from);
            }
            catch
            {
                MessageBox.Show("Wrong input filename!");
                return;
            }
            var data = Parse(bmp);
            for (int i = 0; i < data.Count; i++)
            {
                data[i].Rectangle.Y = bmp.Height - data[i].Rectangle.Y - data[i].Rectangle.Height;
            }

            if (!File.Exists(to))
            {
                try
                {
                    File.Create(to).Close();
                }
                catch
                {
                    MessageBox.Show("Wrong output filename!");
                    return;
                }
            }

            List<LevelInfo> someData = new List<LevelInfo>();

            try
            {
                var jData = JObject.Parse(File.ReadAllText(to));
                var levels = ((JArray)jData.GetValue("levels"));
                foreach (JObject level in levels)
                {
                    LevelInfo info = new LevelInfo();
                    someData.Add(info);
                    info.name = (string)level.GetValue("name");
                    info.x = (int)level.GetValue("x");
                    info.y = (int)level.GetValue("y");
                    info.width = (int)level.GetValue("width");
                    info.height = (int)level.GetValue("height");
                    info.blocks = new int[2];
                    info.blocks[0] = (int)level.GetValue("blocks")[0];
                    info.blocks[1] = (int)level.GetValue("blocks")[1];
                    info.stars = new int[2];
                    info.stars[0] = (int)level.GetValue("stars")[0];
                    info.stars[1] = (int)level.GetValue("stars")[1];
                    info.gravity = (double)level.GetValue("gravity");

                    var allObstacles = new List<Obstacle>();
                    var rawObstacles = ((JArray)level.GetValue("obstacles"));

                    foreach (JObject obstacle in rawObstacles)
                    {
                        var no = new Obstacle();
                        no.x = (int)obstacle.GetValue("x");
                        no.y = (int)obstacle.GetValue("y");
                        no.width = (int)obstacle.GetValue("width");
                        no.height = (int)obstacle.GetValue("height");
                        no.type = (int)obstacle.GetValue("type");
                        no.gravity = (double)obstacle.GetValue("gravity");
                        allObstacles.Add(no);
                    }

                    info.obstacles = allObstacles.ToArray();
                }
            }
            catch
            {

            }

            foreach (var rect in data)
            {
                int level = rect.Color.B;
                LevelInfo info;
                if (someData.Count > level)
                    info = someData[level];
                else
                {
                    info = new LevelInfo();
                    someData.Add(info);
                }


                if (GetTypeByColor(rect.Color) < 10)
                {
                    var obstacles = new List<Obstacle>(info.obstacles ?? new Obstacle[0]);
                    var obstacle = new Obstacle();
                    obstacle.type = GetTypeByColor(rect.Color);
                    obstacle.Rect = rect.Rectangle;

                    bool found = false;
                    foreach (Obstacle o in obstacles)
                    {
                        if (o.x == obstacle.x && o.y == obstacle.y)
                        {
                            found = true;
                            break;
                        }
                    }

                    if (!found)
                    {
                        Console.WriteLine("Saving a new obstacle ...");
                        obstacles.Add(obstacle);
                    }

                    info.obstacles = obstacles.ToArray();
                }
                else
                {
                    if (GetTypeByColor(rect.Color) == 10)
                    {
                        info.from = new TPoint()
                        {
                            x = rect.Rectangle.X,
                            y = rect.Rectangle.Y
                        };
                    }
                    else
                    {
                        info.to = new TPoint()
                        {
                            x = rect.Rectangle.X,
                            y = rect.Rectangle.Y
                        };
                    }
                }
            }

            Serialize(to, someData);
            bmp.Dispose();
            MessageBox.Show("File Saved!");
        }

        private void Serialize(string file, List<LevelInfo> someData)
        {
            Level l = new Level();
            l.levels = someData.ToArray();
            File.WriteAllText(file, JsonConvert.SerializeObject(l, Formatting.Indented));
        }

        private int GetTypeByColor(System.Drawing.Color color)
        {
            if (color.R == 255 && color.G == 0) //simple obstacle
                return 1;
            else if (color.R == 0 && color.G == 255) //dynamic obstacle
                return 5;
            else if (color.R == 128 && color.G == 128) //from block
                return 10;
            else if (color.R == 255 && color.G == 255)
                return 20;
            return -1;
        }

        private List<Rect> Parse(System.Drawing.Bitmap bmp)
        {
            List<Rect> data = new List<Rect>();
            bool checkPoint = false;
            for (int i = 1; i < bmp.Width; i++)
            {
                for (int j = 1; j < bmp.Height; j++)
                {
                    for (int k = 0; k < data.Count; k++)
                    {
                        Rectangle r = data[k].Rectangle;
                        if (r.Contains(new Point(i, j)))
                        {
                            checkPoint = false;
                            break;
                        }
                    }
                    if (checkPoint)
                        if (bmp.GetPixel(i, j) != Color.FromArgb(255, 255, 255))
                        {
                            var r = GetRect(bmp, i, j);
                            if (r != null)
                                data.Add(r);
                        }
                    checkPoint = true;
                }
            }
            return data;
        }

        private Rect GetRect(System.Drawing.Bitmap bmp, int x, int y)
        {
            Color prev = bmp.GetPixel(x, y);
            int xx = 0, yy = 0;
            for (int i = x; i < bmp.Width; i++)
            {
                if (bmp.GetPixel(i, y) == prev)
                    xx = i;
                else
                    break;
            }

            for (int i = y; i < bmp.Height; i++)
            {
                if (bmp.GetPixel(x, i) == prev)
                    yy = i;
                else
                    break;
            }

            Rectangle r = Rectangle.FromLTRB(x, y, xx, yy);
            Rect rr = new Rect();
            rr.Color = prev;
            rr.Rectangle = r;
            return (rr.Rectangle.Width == 0 || rr.Rectangle.Height == 0) ? null : rr;
        }
    }
}
