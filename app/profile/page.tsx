"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { useAccounts } from "@mysten/dapp-kit"
import { Button } from "@/components/ui/button"
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { User, Briefcase, Calendar, Award, Edit } from "lucide-react"
import { queryProfile } from "@/contracts"

interface Profile {
  username: string;
  avatar_url?: string;
  role: string;
  created_at: string;
  completedTasks: number;
  bio: string;
}

interface Board {
  id: string
  name: string
  description: string
  status: "active" | "completed" | "archived"
  createdAt: string
}

// 加载状态组件
function LoadingState() {
  return (
    <div className="space-y-8 animate-pulse">
      <div className="flex items-center space-x-6">
        <Skeleton className="h-24 w-24 rounded-full" />
        <div className="space-y-2">
          <Skeleton className="h-6 w-48" />
          <Skeleton className="h-4 w-32" />
        </div>
      </div>
      <Card>
        <CardContent className="p-6">
          <div className="space-y-4">
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-3/4" />
            <Skeleton className="h-4 w-1/2" />
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default function ProfilePage() {
  const router = useRouter()
  const { currentAccount } = useAccounts()
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [profile, setProfile] = useState<Profile | null>(null)
  const [createdBoards, setCreatedBoards] = useState<Board[]>([])
  const [participatedBoards, setParticipatedBoards] = useState<Board[]>([])
  const [isEditing, setIsEditing] = useState(false)
  const [redirectRequired, setRedirectRequired] = useState(false)

  // 模拟数据 - 后续可替换为真实数据
  const mockBoards: Board[] = [
    {
      id: "1",
      name: "Development Tasks",
      description: "Frontend and backend development tasks",
      status: "active",
      createdAt: "2024-01-01",
    },
    {
      id: "2",
      name: "Design Projects",
      description: "UI/UX design projects",
      status: "completed",
      createdAt: "2024-01-15",
    },
  ]

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        if (!currentAccount?.address) return
        const profileData = await queryProfile(currentAccount.address)
        setProfile(profileData)
      } catch (err) {
        console.error("Failed to fetch profile:", err)
        setError("Failed to load profile data")
      } finally {
        setLoading(false)
      }
    }

    fetchProfile()
  }, [currentAccount?.address])

  useEffect(() => {
    if (redirectRequired) {
      router.push('/create-profile?redirect=profile')
    }
  }, [redirectRequired, router])

  const handleEditProfile = () => {
    setIsEditing(true)
  }

  const handleSaveProfile = async (event: React.FormEvent) => {
    event.preventDefault()
    // Implement profile update logic here
    setIsEditing(false)
  }

  if (loading) return <LoadingState />

  if (error) {
    return (
      <Alert variant="destructive" className="max-w-2xl mx-auto">
        <AlertDescription>{error}</AlertDescription>
      </Alert>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl space-y-8 animate-fadeIn">
      {/* Profile Header */}
      <div className="flex justify-between items-start">
        <div className="flex items-center space-x-6">
          <Avatar className="h-24 w-24 border-4 border-[var(--h2o-secondary)] shadow-lg">
            <AvatarImage src={profile?.avatar_url} />
            <AvatarFallback className="bg-[var(--h2o-primary)] text-white text-2xl">
              {profile?.username?.charAt(0).toUpperCase() || "U"}
            </AvatarFallback>
          </Avatar>
          <div>
            <h1 className="text-3xl font-bold text-[var(--h2o-accent)]">
              {profile?.username || "Anonymous User"}
            </h1>
            <div className="flex items-center space-x-2 mt-2">
              <Badge className="bg-[var(--h2o-secondary)] text-[var(--h2o-accent)]">
                <Briefcase className="w-3 h-3 mr-1" />
                {profile?.role || "Member"}
              </Badge>
              <Badge variant="outline">
                <Calendar className="w-3 h-3 mr-1" />
                Joined {new Date(profile?.created_at || Date.now()).toLocaleDateString()}
              </Badge>
            </div>
          </div>
        </div>
        <Button
          onClick={() => router.push("/settings")}
          variant="outline"
          className="hover:bg-[var(--h2o-secondary)] hover:text-[var(--h2o-accent)] click-scale"
        >
          <Edit className="w-4 h-4 mr-2" />
          Edit Profile
        </Button>
      </div>

      {/* Profile Stats */}
      <Card className="hover-elevate">
        <CardContent className="p-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="flex items-center space-x-4">
              <div className="p-3 rounded-full bg-[var(--h2o-softbg)]">
                <Award className="w-6 h-6 text-[var(--h2o-accent)]" />
              </div>
              <div>
                <p className="text-sm text-muted-foreground">Completed Tasks</p>
                <p className="text-2xl font-bold text-[var(--h2o-accent)]">
                  {profile?.completedTasks || 0}
                </p>
              </div>
            </div>
            {/* Add more stats here */}
          </div>
        </CardContent>
      </Card>

      {/* Boards and Activities */}
      <Tabs defaultValue="created" className="space-y-6">
        <TabsList className="bg-[var(--h2o-softbg)]">
          <TabsTrigger 
            value="created"
            className="data-[state=active]:bg-[var(--h2o-primary)] data-[state=active]:text-white"
          >
            Created Boards
          </TabsTrigger>
          <TabsTrigger 
            value="joined"
            className="data-[state=active]:bg-[var(--h2o-primary)] data-[state=active]:text-white"
          >
            Joined Boards
          </TabsTrigger>
        </TabsList>

        <TabsContent value="created" className="space-y-4">
          {mockBoards.map((board) => (
            <Card key={board.id} className="hover-elevate transition-all duration-300">
              <CardHeader>
                <div className="flex justify-between items-start">
                  <CardTitle className="text-xl text-[var(--h2o-accent)]">{board.name}</CardTitle>
                  <Badge variant={
                    board.status === "active" ? "default" :
                    board.status === "completed" ? "success" : "secondary"
                  } className="bg-[var(--h2o-secondary)] text-[var(--h2o-accent)]">
                    {board.status}
                  </Badge>
                </div>
                <CardDescription>{board.description}</CardDescription>
              </CardHeader>
              <CardFooter className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">
                  Created on {new Date(board.createdAt).toLocaleDateString()}
                </span>
                <Button 
                  variant="outline" 
                  size="sm"
                  className="hover:bg-[var(--h2o-secondary)] hover:text-[var(--h2o-accent)] click-scale"
                  onClick={() => router.push(`/board/${board.id}`)}
                >
                  View Board
                </Button>
              </CardFooter>
            </Card>
          ))}
        </TabsContent>

        <TabsContent value="joined" className="space-y-4">
          {/* Similar structure for joined boards */}
        </TabsContent>
      </Tabs>
    </div>
  )
}

